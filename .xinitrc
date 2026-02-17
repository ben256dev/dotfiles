#!/bin/sh
xset s off; xset -dpms; xset s noblank
feh --bg-scale ~/Pictures/wallpaper.jpg &
picom --backend xrender &
sxhkd &
exec dbus-launch --exit-with-session bspwm
