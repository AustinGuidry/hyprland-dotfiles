#!/usr/bin/env bash
# Toggle the eww dashboard and its Hyprland submap together, so that Escape
# only closes the dashboard while it is actually open (a bare Escape bind
# would otherwise grab the key compositor-wide, breaking Escape everywhere
# else -- rofi, vim, browser fullscreen, dialogs...).
#
# We decide open-vs-close from eww's state *before* touching anything, then
# move the window and the submap to match that decision. The previous version
# toggled first and then polled `eww active-windows` after a 50ms sleep to
# guess the new state -- eww maps/unmaps the layer surface asynchronously, so
# under load that poll could read the stale state and leave the submap out of
# sync with the window (dashboard open but submap "default", so Escape did
# nothing).
set -euo pipefail

# Switching submaps must go through `hyprctl eval` on the Lua config -- a plain
# `hyprctl dispatch submap reset` is parsed as Lua and errors out.
enter_submap() { hyprctl eval "hl.dispatch(hl.dsp.submap(\"$1\"))" >/dev/null; }

if eww active-windows 2>/dev/null | grep -q '^dashboard:'; then
    eww close dashboard
    enter_submap reset
else
    eww open dashboard
    enter_submap dashboard
fi
