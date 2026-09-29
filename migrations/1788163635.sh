echo "Remove legacy temporary passwordless sudo grants"

# The privileged step hands this helper to sudo, so its path must never be
# derived from OMARCHY_PATH: bin/omarchy-migrate honors OMARCHY_PATH from the
# user's environment, and a steered value would execute an attacker-chosen
# binary as root. The package always installs the helper at /usr/bin; a
# checkout without the installed copy never created packaged grants, so there
# is nothing to migrate and the script exits quietly.
helper=/usr/bin/omarchy-sudo-passwordless
[[ -x $helper ]] || exit 0

if ! "$helper" __migration-complete; then
  sudo "$helper" __migrate
fi
