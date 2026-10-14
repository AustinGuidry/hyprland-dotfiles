#!/usr/bin/env bash
# Make a qylock theme the SDDM login screen. Needs root, so the picker runs it
# through pkexec:
#
#     sddm-theme.sh <qylock themes folder> <theme name>
#
# This is qylock's sddm.sh without the questions: copy the theme into SDDM's
# themes folder (the sddm user cannot read a home directory, so a symlink won't
# do) and name it in theme.conf. SDDM rereads its config each time it brings up
# a greeter, so the next logout shows the theme; nothing needs restarting.
#
# As in sddm.sh, a clockwork variant is installed under its own name:
# clockwork/tape becomes "tape".

set -euo pipefail

system=/usr/share/sddm/themes
conf=/etc/sddm.conf.d/theme.conf

# Left in every theme installed from here, so the next pick can clear the last
# one away without touching anything this script did not put there.
marker=.from-lockpicker

die() {
    echo "$*" >&2
    exit 1
}

[[ $# -eq 2 ]] || die "usage: ${0##*/} <qylock themes folder> <theme name>"
[[ $EUID -eq 0 ]] || die "Changing the SDDM theme needs root."

name="$2"
installed="${name##*/}"

# The name ends up in an rm -rf run as root: nothing but what themes are called.
plain='[A-Za-z0-9_][A-Za-z0-9_-]*'
[[ "$name" =~ ^$plain(/$plain)?$ ]] || die "Not a theme name: $name"

source="$(realpath -- "$1")/$name"
[[ -f "$source/Main.qml" && -f "$source/metadata.desktop" ]] || die "No SDDM theme in $source"

previous=""
if [[ -f "$conf" ]]; then
    previous="$(sed -n 's/^Current=//p' "$conf" | tail -n 1)"
fi

mkdir -p "$system" "$(dirname "$conf")"

# Copy next to the destination and swap, so a copy that fails leaves the old
# theme whole.
staging="$(mktemp -d "$system/.lockpicker.XXXXXX")"
trap 'rm -rf -- "$staging"' EXIT
cp -r -- "$source/." "$staging/"
touch "$staging/$marker"
chmod -R u=rwX,go=rX "$staging"
rm -rf -- "${system:?}/$installed"
mv -- "$staging" "$system/$installed"

if [[ ! -s "$conf" ]]; then
    printf '[Theme]\nCurrent=%s\n' "$installed" > "$conf"
elif grep -q '^Current=' "$conf"; then
    sed -i "s|^Current=.*|Current=$installed|" "$conf"
elif grep -q '^\[Theme\]' "$conf"; then
    sed -i "/^\[Theme\]/a Current=$installed" "$conf"
else
    printf '\n[Theme]\nCurrent=%s\n' "$installed" >> "$conf"
fi

# The theme this one replaces, if it came from here as well; they run to 75M.
if [[ "$previous" != "$installed" && "$previous" =~ ^$plain$ && -f "$system/$previous/$marker" ]]; then
    rm -rf -- "${system:?}/$previous"
fi
