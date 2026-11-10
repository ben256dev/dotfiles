#!/usr/bin/env bash
set -euo pipefail

dev=$(upower -e | grep -E 'battery|BAT' | head -n1 || true)
[ -z "${dev}" ] && exit 0

pct=$(upower -i "$dev" | awk -F': *' '/percentage/ { gsub(/%/,"",$2); print int($2) }')
[ -z "${pct}" ] && exit 0

if   [ "$pct" -le 10 ]; then icon="󰂎"
elif [ "$pct" -le 20 ]; then icon="󰁺"
elif [ "$pct" -le 30 ]; then icon="󰁻"
elif [ "$pct" -le 40 ]; then icon="󰁼"
elif [ "$pct" -le 50 ]; then icon="󰁽"
elif [ "$pct" -le 60 ]; then icon="󰁾"
elif [ "$pct" -le 70 ]; then icon="󰁿"
elif [ "$pct" -le 80 ]; then icon="󰂀"
elif [ "$pct" -le 90 ]; then icon="󰂁"
elif [ "$pct" -le 95 ]; then icon="󰂂"
else                         icon="󰁹"
fi

printf '%s %s%%\n' "$icon" "$pct"

