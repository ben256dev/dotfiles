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
TEMPLATE="$HOME/.kmonad/colemakdh.kbd"
CONFIG=/etc/kmonad/dotfiles.kbd
[ ! -r "$HOME/.config/dotfiles/machine.sh" ] || . "$HOME/.config/dotfiles/machine.sh"

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user (it uses sudo itself)." >&2
    exit 1
fi
[ -f "$TEMPLATE" ] || { echo "Missing $TEMPLATE (run install.sh first)." >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
if [[ "$("$KMONAD_BIN" --version 2>/dev/null | head -n1)" != "$KMONAD_VERSION,"* ]]; then
    curl -fsSL -o "$tmp/kmonad" "https://github.com/kmonad/kmonad/releases/download/$KMONAD_VERSION/kmonad"
    echo "$KMONAD_SHA256  $tmp/kmonad" | sha256sum --check --quiet -
    sudo install -m 755 "$tmp/kmonad" "$KMONAD_BIN"
fi

# Render the portable layout with this machine's input device.
python3 - "$TEMPLATE" "$tmp/config.kbd" "${KMONAD_DEVICE:-}" <<'PYCONFIG'
import json, pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text()
if sys.argv[3]:
    replacement = '(device-file ' + json.dumps(sys.argv[3]) + ')'
    text = re.sub(r'\(device-file "[^"\n]*"\)', lambda _: replacement, text, count=1)
pathlib.Path(sys.argv[2]).write_text(text)
PYCONFIG
"$KMONAD_BIN" --dry-run "$tmp/config.kbd"
device="$(sed -n 's/.*device-file "\([^"]*\)".*/\1/p' "$tmp/config.kbd" | head -n1)"
[ -e "$device" ] || { echo "Keyboard device not found: $device" >&2; exit 2; }
sudo install -d -m 755 /etc/kmonad
sudo install -m 644 "$tmp/config.kbd" "$CONFIG"
sudo modprobe uinput
printf 'uinput\n' | sudo tee /etc/modules-load.d/kmonad.conf >/dev/null

sudo tee "/etc/systemd/system/$SERVICE.service" > /dev/null <<EOF
[Unit]
Description=KMonad keyboard remapping ($CONFIG)
StartLimitIntervalSec=0

[Service]
ExecStart=$KMONAD_BIN $CONFIG
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload

sudo systemctl enable --quiet "$SERVICE"
sudo systemctl reset-failed "$SERVICE"
sudo systemctl restart "$SERVICE"
sleep 1
sudo systemctl is-active --quiet "$SERVICE"
echo "kmonad is running: the keyboard is now Colemak-DH (Right Alt + Left Win toggles QWERTY)."
