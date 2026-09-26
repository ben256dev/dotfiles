#!/bin/sh

if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
    exec wl-copy
fi

if [ -n "${DISPLAY:-}" ] && command -v xclip >/dev/null 2>&1; then
    exec xclip -selection clipboard -in
fi

exit 1
