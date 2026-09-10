#!/usr/bin/env bash
# Toggle the eww keybind cheatsheet and its Hyprland submap together, so that
# Escape only closes the cheatsheet while it is actually open. Same rationale
# and mechanism as toggle-dashboard.sh -- see that script for the full notes.
set -euo pipefail

# Switching submaps must go through `hyprctl eval` on the Lua config -- a plain
# `hyprctl dispatch submap reset` is parsed as Lua and errors out.
enter_submap() { hyprctl eval "hl.dispatch(hl.dsp.submap(\"$1\"))" >/dev/null; }

if eww active-windows 2>/dev/null | grep -q '^cheatsheet:'; then
    eww close cheatsheet
    enter_submap reset
else
    eww open cheatsheet
    enter_submap cheatsheet
fi
