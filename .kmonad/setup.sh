#!/bin/bash
# Install kmonad and run colemakdh.kbd as a boot-time service. install.sh runs
# this; run it yourself after changing the keyboard device in colemakdh.kbd.
# Safe to rerun.
set -euo pipefail

KMONAD_VERSION=0.4.3
KMONAD_SHA256=89cc104d877234cbe62987b5bf37a441cf9ab59f28ca7e3f80e6f2502429edb4
# Root-owned, because the service runs it as root.
KMONAD_BIN=/usr/local/bin/kmonad
SERVICE=keyboard_mylaptop
CONFIG="$HOME/.kmonad/colemakdh.kbd"

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user (it uses sudo itself)." >&2
    exit 1
fi
[ -f "$CONFIG" ] || { echo "Missing $CONFIG (run install.sh first)." >&2; exit 1; }

if [[ "$("$KMONAD_BIN" --version 2>/dev/null | head -n1)" != "$KMONAD_VERSION,"* ]]; then
    tmp="$(mktemp -d)"
    trap 'rm -rf -- "$tmp"' EXIT
    curl -fsSL -o "$tmp/kmonad" "https://github.com/kmonad/kmonad/releases/download/$KMONAD_VERSION/kmonad"
    echo "$KMONAD_SHA256  $tmp/kmonad" | sha256sum --check --quiet -
    sudo install -m 755 "$tmp/kmonad" "$KMONAD_BIN"
fi

"$KMONAD_BIN" --dry-run "$CONFIG"

sudo tee "/etc/systemd/system/$SERVICE.service" > /dev/null <<EOF
[Unit]
Description=KMonad keyboard remapping ($CONFIG)

[Service]
ExecStart=$KMONAD_BIN $CONFIG
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload

# Only enable it if the keyboard named on the config's input line exists;
# otherwise the service would just fail and restart forever.
device="$(sed -n 's/.*device-file "\([^"]*\)".*/\1/p' "$CONFIG" | head -n1)"
if [ ! -e "$device" ]; then
    echo "Keyboard device not found: $device" >&2
    echo "Put your keyboard's path on the input line of $CONFIG (see .kmonad/README.md), then run this again." >&2
    exit 2
fi
sudo systemctl enable --quiet "$SERVICE"
sudo systemctl restart "$SERVICE"
echo "kmonad is running: the keyboard is now Colemak-DH (Right Alt + Left Win toggles QWERTY)."
