#!/usr/bin/env bash
# Pair / reconnect AirPods on Arch (bluez + wireplumber).
#
# Usage:
#   pair-airpods.sh          # scan, show candidate devices, pair the one you pick
#   pair-airpods.sh <MAC>    # pair/connect a known MAC directly
#
# Before running: lid OPEN, both buds IN the case, then press and HOLD the
# button on the back of the case ~5-10s until the status light flashes WHITE.

set -euo pipefail

power_on() {
    bluetoothctl power on >/dev/null
    bluetoothctl agent on   >/dev/null 2>&1 || true
    bluetoothctl default-agent >/dev/null 2>&1 || true
}

pair_mac() {
    local mac="$1"
    echo ">> pairing $mac"
    bluetoothctl --timeout 20 scan on >/dev/null 2>&1 &
    local scanpid=$!
    sleep 3
    bluetoothctl pair "$mac"    || true
    bluetoothctl trust "$mac"   || true
    bluetoothctl connect "$mac" || true
    kill "$scanpid" 2>/dev/null || true
    echo
    bluetoothctl info "$mac" | grep -E 'Name|Alias|Paired|Trusted|Connected'
    echo
    echo ">> if audio doesn't route automatically:"
    echo "   wpctl status | grep -i airpod"
    echo "   wpctl set-default <id>"
}

power_on

if [[ $# -ge 1 ]]; then
    pair_mac "$1"
    exit 0
fi

echo ">> scanning 12s -- make sure the case light is flashing WHITE now"
bluetoothctl --timeout 12 scan on >/dev/null 2>&1 || true
sleep 12

echo
echo ">> candidate devices (named, or Apple vendor id 0x004c):"
mapfile -t cands < <(
    for m in $(bluetoothctl devices | awk '{print $2}'); do
        info=$(bluetoothctl info "$m")
        name=$(echo "$info" | awk -F': ' '/\tName:/{print $2; exit}')
        apple=$(echo "$info" | grep -c '0x004c' || true)
        if [[ -n "$name" || "$apple" != "0" ]]; then
            printf '%s\t%s\n' "$m" "${name:-<no name, Apple device>}"
        fi
    done
)

if [[ ${#cands[@]} -eq 0 ]]; then
    echo "   none found. The AirPods are probably not in pairing mode."
    echo "   Hold the case button until the light flashes WHITE, then rerun."
    exit 1
fi

i=1
for line in "${cands[@]}"; do
    echo "   [$i] $line"
    ((i++))
done

read -rp ">> pick a number (or q): " pick
[[ "$pick" == "q" ]] && exit 0
sel="${cands[$((pick-1))]}"
mac="${sel%%$'\t'*}"
pair_mac "$mac"
