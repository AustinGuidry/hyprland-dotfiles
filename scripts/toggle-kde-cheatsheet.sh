#!/usr/bin/env bash
# Toggle the eww keybind cheatsheet under KDE Plasma. Press Super+K again to
# close it -- Escape-to-close was tried via a dynamically registered global
# shortcut, but that requires a kglobalaccel restart on every open/close and
# proved unreliable (race between the restart finishing and the keypress), so
# it was reverted in favor of this simple, always-reliable toggle.
set -euo pipefail

EWW_CONFIG="$HOME/.config/eww-kde"

if eww --config "$EWW_CONFIG" active-windows 2>/dev/null | grep -q '^cheatsheet:'; then
    eww --config "$EWW_CONFIG" close cheatsheet
else
    eww --config "$EWW_CONFIG" open cheatsheet
fi
