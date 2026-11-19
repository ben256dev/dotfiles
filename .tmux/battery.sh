#!/bin/sh
# Battery for tmux's status bar (@onedark_widgets in .tmux.conf), read from
# upower. Prints nothing on machines without a battery.

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
        ;;
esac

# Low and not charging: at 20% and below the text turns One Dark's red; at
# 10% and below it becomes a blinking red badge. Each ends by restoring the
# theme's widget colours, since the theme's next segment doesn't clear blink.
reset='#[fg=#aab2bf,bg=#3e4452,nobold,noblink]'
if [ "$icon" != "󰂄" ] && [ "$pct" -le 10 ]; then
    printf '#[fg=#282c34,bg=#e06c75,bold,blink] %s %s%% %s\n' "$icon" "$pct" "$reset"
elif [ "$icon" != "󰂄" ] && [ "$pct" -le 20 ]; then
    printf '#[fg=#e06c75,bold]%s %s%%%s\n' "$icon" "$pct" "$reset"
else
    printf '%s %s%%\n' "$icon" "$pct"
fi
