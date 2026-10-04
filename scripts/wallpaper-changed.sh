#!/bin/bash
echo "$(date): Called with: $1" >> ~/wallpaper-debug.log
export WAYLAND_DISPLAY=wayland-1
export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
WALLPAPER="${1/#\~/$HOME}"

# (The ripple from the click is not started here: by the time the picker runs
# this hook it is a quarter-second late. Hyprland spots the pick itself -- see
# the ripple section of hypr/config/look_feel.lua.)

# matugen also writes ~/.config/quickshell/desktop/colors.json; the shell
# watches that file and recolors itself, so nothing needs restarting.
#
# Reading the image is the slow part -- 50 ms for a small one, 2 s for a 4K
# PNG -- yet the whole palette follows from the single source color matugen
# picks out of it. So remember that color per image: generating from it gives
# the identical palette in about 10 ms. The key covers the file's mtime and
# size, so an edited wallpaper is read afresh.
PREFER=saturation
cache="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-source-color"
key=$(stat -c "%n %Y %s $PREFER" "$WALLPAPER" | sha1sum | cut -d' ' -f1)
source_color=$(cat "$cache/$key" 2>/dev/null)

if [[ $source_color =~ ^#[0-9a-fA-F]{6}$ ]]; then
    matugen color hex "$source_color" >> ~/wallpaper-debug.log 2>&1
else
    source_color=$(matugen image "$WALLPAPER" --prefer="$PREFER" --json hex 2>> ~/wallpaper-debug.log \
        | jq -r '.colors.source_color.default.color')
    if [[ $source_color =~ ^#[0-9a-fA-F]{6}$ ]]; then
        mkdir -p "$cache"
        echo "$source_color" > "$cache/$key"
    fi
fi
