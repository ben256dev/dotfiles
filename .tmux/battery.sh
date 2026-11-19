#!/bin/sh
# Battery for tmux's status bar (@onedark_widgets in .tmux.conf), read from
# upower. Prints nothing on machines without a battery. Turns red at 20% and
# below unless it's charging, so it's hard to miss.

dev=$(upower -e 2>/dev/null | grep -m1 battery_) || exit 0
info=$(upower -i "$dev")
pct=$(printf '%s\n' "$info" | awk -F': *' '/percentage:/ { print int($2) }')
state=$(printf '%s\n' "$info" | awk -F': *' '/state:/ { print $2 }')
[ -n "$pct" ] || exit 0

case $state in
    charging|fully-charged|pending-charge) icon="󰂄" ;;
    *)
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
        # One Dark's red; the theme's next segment sets its own colours.
        [ "$pct" -le 20 ] && printf '#[fg=#e06c75,bold]'
        ;;
esac

printf '%s %s%%\n' "$icon" "$pct"
