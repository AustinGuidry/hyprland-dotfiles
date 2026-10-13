#!/usr/bin/env bash
# List the qylock themes for the picker, one per line:
#
#     <theme name><TAB><preview image, or nothing>
#
# $1 is the themes folder the lock screen uses. A theme is any folder in it
# holding a Main.qml; clockwork keeps its variants one level down, hence names
# like "clockwork/tape". The name is what goes in ~/.config/qylock/theme.
#
# Previews are the GIFs qylock ships for its README, in Assets/ next to the
# themes in the checkout. A theme without one falls back to its own backdrop.

set -euo pipefail

themes="$(realpath "$1")"
assets="$(dirname "$themes")/Assets"

# GIFs are named loosely after their theme (dog_samurai.gif for dog-samurai),
# so compare with case and -/_ folded.
fold() {
    local s="${1,,}"
    echo "${s//-/_}"
}

declare -A gifs
for gif in "$assets"/*.gif; do
    [[ -f "$gif" ]] || continue
    gifs["$(fold "$(basename "$gif" .gif)")"]="$gif"
done

# The ones folding doesn't reach.
declare -A renamed=(
    [last_of_us]=the_last_of_us
    [windows_7]=win7
)

cd "$themes"
find -L . -mindepth 2 -maxdepth 3 -name Main.qml -printf '%h\n' | sed 's|^\./||' | sort -f |
    while read -r name; do
        key="$(fold "${name%%/*}")"
        key="${renamed[$key]:-$key}"
        preview="${gifs[$key]:-}"

        if [[ -z "$preview" ]]; then
            for still in "$themes/$name"/{bg,background}.{png,jpg,jpeg,webp}; do
                if [[ -f "$still" ]]; then
                    preview="$still"
                    break
                fi
            done
        fi

        printf '%s\t%s\n' "$name" "$preview"
    done
