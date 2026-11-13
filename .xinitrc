#!/bin/sh
if [ -r "$HOME/.config/dotfiles/machine.sh" ]; then
    . "$HOME/.config/dotfiles/machine.sh"
fi
if command -v machine_display_setup >/dev/null 2>&1; then
    machine_display_setup
fi
xset s off
xset -dpms
xset s noblank
exec dbus-launch --exit-with-session bspwm
