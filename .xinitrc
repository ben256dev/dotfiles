#!/bin/sh
xset s off; xset -dpms; xset s noblank
exec dbus-launch --exit-with-session bspwm
