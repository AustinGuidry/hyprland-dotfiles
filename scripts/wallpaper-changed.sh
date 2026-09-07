#!/bin/bash
echo "$(date): Called with: $1" >> ~/wallpaper-debug.log
export WAYLAND_DISPLAY=wayland-1
export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
WALLPAPER="${1/#\~/$HOME}"
matugen image "$WALLPAPER" --source-color-index 0 >> ~/wallpaper-debug.log 2>&1
eww reload >> ~/wallpaper-debug.log 2>&1
pkill waybar
sleep 0.5
waybar &
