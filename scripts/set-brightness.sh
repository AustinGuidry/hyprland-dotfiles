#!/bin/bash
VAL=$(echo "$1" | cut -d. -f1)
if [ "$VAL" -lt 1000 ]; then
    exit 0
fi
brightnessctl set "$VAL"
