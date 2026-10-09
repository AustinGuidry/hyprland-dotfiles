#!/usr/bin/env bash
# Battery log: one CSV row per sample in ~/.local/state/battery/log.csv, flushed
# to disk each time so the last row survives the power cut when the pack gives
# out. The gauge's percentage reads high on a worn pack; the rows just before a
# death show where empty really is, in percent and in volts.
#
# Every launch writes a `start` row and every clean exit a `stop` row, so a
# Discharging row directly followed by `start` is a death (or a forced
# power-off, or running flat while suspended -- the timestamps tell):
#   grep -B3 ,start ~/.local/state/battery/log.csv
#
# Started from hypr/config/autostart.lua.
set -uo pipefail

bat=$(grep -lx Battery /sys/class/power_supply/*/type 2>/dev/null | head -n1)
bat=${bat%/type}
for f in status voltage_now current_now charge_now charge_full; do
    [[ -r $bat/$f ]] || exit 0
done

dir="${XDG_STATE_HOME:-$HOME/.local/state}/battery"
log="$dir/log.csv"
mkdir -p "$dir"

# One logger at a time, however often the session is restarted.
exec 9> "$dir/lock"
flock -n 9 || exit 0

[[ -s $log ]] || echo "time,status,mV,mA,mAh,pct" > "$log"

row() {
    echo "$(date +%FT%T),$1" >> "$log"
    sync "$log"
}

# The sleep runs in the background so a signal is handled at once rather than
# when it finishes; shutdown doesn't wait that long before killing.
sleeper=
trap 'kill $sleeper 2>/dev/null; row stop,,,,; exit 0' TERM INT HUP
row start,,,,

while :; do
    status=$(< "$bat/status")
    full=$(< "$bat/charge_full")
    if [[ ($status == Discharging || $status == Charging) && $full -gt 0 ]]; then
        charge=$(< "$bat/charge_now")
        current=$(< "$bat/current_now")
        pct=$(( charge * 1000 / full ))  # tenths; the same ratio UPower shows
        row "$status,$(( $(< "$bat/voltage_now") / 1000 )),$(( ${current#-} / 1000 )),$(( charge / 1000 )),$(( pct / 10 )).$(( pct % 10 ))"
    fi
    # Often enough on battery that the last row is close to the end.
    [[ $status == Discharging ]] && pause=10 || pause=60
    sleep "$pause" 9>&- &
    sleeper=$!
    wait "$sleeper"
done
