# Settings for shthub. Tracked on migration/shthub; review before merging to main.
KMONAD_DEVICE='/dev/input/by-id/usb-Kingston_HyperX_Alloy_FPS_Mechanical_Gaming_Keyboard-event-kbd'

machine_display_setup() {
    if xrandr --query | grep -q '^DisplayPort-0 connected' &&
       xrandr --query | grep -q '^HDMI-A-0 connected'; then
        xrandr --output DisplayPort-0 --mode 1920x1080 --rotate normal --pos 0x630 \
            --output HDMI-A-0 --mode 1920x1080 --rotate right --pos 1920x0 --primary
    fi
}

FIREFOX_GTK_PREFIX="$HOME/.local/opt/gtk-3.24.52"
