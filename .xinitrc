#!/bin/sh
if [ -r "$HOME/.config/dotfiles/machine.sh" ]; then
    . "$HOME/.config/dotfiles/machine.sh"
fi
if command -v machine_display_setup >/dev/null 2>&1; then
    machine_display_setup
fi
exec dbus-launch --exit-with-session bspwm
