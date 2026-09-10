#!/usr/bin/env bash
# Toggle kitty's background transparency on/off for every running kitty window.
# kitty keeps text fully opaque either way -- only the background alpha changes.
# Bound to a Hyprland hotkey; kitty must have `allow_remote_control yes` and
# `listen_on unix:/tmp/kitty` set (see ~/.config/kitty/kitty.conf). kitty
# appends the pid, so each instance listens on /tmp/kitty-<pid>.
set -uo pipefail

OPAQUE="1.0"
TRANSPARENT="0.65"   # keep in sync with background_opacity in kitty.conf

shopt -s nullglob
sockets=(/tmp/kitty-*)
[[ ${#sockets[@]} -eq 0 ]] && exit 0

# Decide the target from the first reachable window's current opacity.
target="$OPAQUE"
for s in "${sockets[@]}"; do
    current=$(kitten @ --to "unix:$s" ls 2>/dev/null \
        | jq -r '[.[].background_opacity] | first // empty')
    [[ -z "$current" ]] && continue
    if [[ "$current" == "1" || "$current" == "1.0" ]]; then
        target="$TRANSPARENT"
    else
        target="$OPAQUE"
    fi
    break
done

for s in "${sockets[@]}"; do
    kitten @ --to "unix:$s" set-background-opacity "$target" 2>/dev/null || true
done
