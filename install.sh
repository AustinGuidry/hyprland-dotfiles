#!/usr/bin/env bash
# Symlink this repo's configs into $HOME.
# Anything already present is moved into a timestamped backup first.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# repo path  ->  path under $HOME
LINKS=(
    ".config/hypr"
    ".config/matugen"
    ".config/waybar"
    ".config/eww"
    ".config/rofi"
    ".config/kitty"
    ".config/ashell"
    ".config/waypaper"
    ".config/networkmanager-dmenu"
    ".config/qylock"
    "scripts"
)

link() {
    local rel="$1"
    local src="$REPO/$rel"
    local dst="$HOME/$rel"

    if [[ -L "$dst" ]]; then
        if [[ "$(readlink -f "$dst")" == "$src" ]]; then
            echo "  ok      $rel (already linked)"
            return
        fi
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        mkdir -p "$BACKUP/$(dirname "$rel")"
        mv "$dst" "$BACKUP/$rel"
        echo "  backup  $rel -> $BACKUP/$rel"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "  link    $rel"
}

echo "Linking dotfiles from $REPO"
for rel in "${LINKS[@]}"; do
    link "$rel"
done

chmod +x "$REPO"/scripts/*.sh

echo
if [[ -d "$BACKUP" ]]; then
    echo "Replaced files were saved to $BACKUP"
fi
echo "Done. Reload with: hyprctl reload"
