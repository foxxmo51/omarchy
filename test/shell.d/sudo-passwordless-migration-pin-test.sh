#!/bin/bash
#
# migrations/1788163635.sh hands its helper to sudo. The helper path must be
# the installed /usr/bin copy, never derived from the user-controlled
# OMARCHY_PATH: bin/omarchy-migrate honors OMARCHY_PATH from the user's
# environment, so a steered value would otherwise execute an attacker-chosen
# binary as root. The real migration runs here; only sudo is stubbed (it
# records instead of elevating), and the "installed" branch is skipped when
# the packaged helper is absent, which is exactly the dev-checkout case the
# migration must handle without touching the steered tree.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

migration="$ROOT/migrations/1788163635.sh"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

stub_bin="$test_dir/bin"
evil="$test_dir/evil"
mkdir -p "$stub_bin" "$evil/bin"

# The attacker's tree: a trojaned helper that records any execution and
# reports the migration as incomplete so the sudo step would run.
cat >"$evil/bin/omarchy-sudo-passwordless" <<'STUB'
#!/bin/bash
echo "helper executed: $*" >>"${HELPER_CALLS:?}"
[[ $1 == __migration-complete ]] && exit 1
exit 0
STUB
chmod +x "$evil/bin/omarchy-sudo-passwordless"

# sudo records the exact argv it would elevate instead of elevating.
sudo_calls="$test_dir/sudo-calls"
cat >"$stub_bin/sudo" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"${SUDO_CALLS:?}"
STUB
chmod +x "$stub_bin/sudo"

export HELPER_CALLS="$test_dir/helper-calls" SUDO_CALLS="$sudo_calls"
: >"$HELPER_CALLS"

# On a real Omarchy install the packaged helper exists and the pinned path is
# used; this sandbox has no /usr/bin copy, which is the dev-checkout case.
if [[ -x /usr/bin/omarchy-sudo-passwordless ]]; then
  skip "installed helper present; cannot simulate its absence"
fi

PATH="$stub_bin:$PATH" OMARCHY_PATH="$evil" bash "$migration" \
  || fail "migration failed under a steered OMARCHY_PATH"

[[ ! -s $HELPER_CALLS ]] || fail "steered helper was executed" "$(cat "$HELPER_CALLS")"
[[ ! -f $sudo_calls ]] || fail "sudo was invoked from the steered tree" "$(cat "$sudo_calls")"
pass "steered OMARCHY_PATH cannot reach sudo through the passwordless migration"
