#!/bin/sh
# One-time setup for the bar's Surfshark menu.
#
# surfshark-vpn only runs as root, so the menu can't drive it directly. This
# installs a root-owned copy of surfshark-helper and a sudoers rule that lets
# one user run that copy -- and only that copy -- without a password. Anything
# running as that user can then list locations and bring the VPN up or down,
# which is the point; the helper offers nothing else.
#
#   sudo ./install.sh            install, or update after editing the helper
#   sudo ./install.sh --remove   undo both
set -eu

helper=/usr/local/libexec/surfshark-bar-helper
rule=/etc/sudoers.d/surfshark-bar
here=$(cd "$(dirname "$0")" && pwd)

[ "$(id -u)" -eq 0 ] || { echo "Run this with sudo: sudo $0" >&2; exit 1; }

if [ "${1-}" = --remove ]; then
    rm -f "$helper" "$rule"
    echo "Removed $helper and $rule."
    exit 0
fi

user=${SUDO_USER-}
case $user in
    '' | root | *[!A-Za-z0-9._-]*)
        echo "Run this with sudo from your own account, so it knows who to allow." >&2
        exit 1 ;;
esac
id "$user" > /dev/null

install -D -o root -g root -m 0755 "$here/surfshark-helper" "$helper"

# A sudoers file with a syntax error locks sudo out entirely, so the rule is
# checked on its own before it goes in, and the whole policy again after.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" <<EOF
# Bar VPN menu (quickshell/desktop/vpn). Undo with: install.sh --remove
$user ALL=(root) NOPASSWD: $helper
EOF
visudo -cf "$tmp" > /dev/null
install -o root -g root -m 0440 "$tmp" "$rule"
if ! visudo -c > /dev/null; then
    rm -f "$rule"
    echo "sudo rejected the new rule; removed it again." >&2
    exit 1
fi

echo "Installed $helper"
echo "Installed $rule:"
sed 's/^/    /' "$rule"
echo "The shield menu in the bar can now switch the VPN."
