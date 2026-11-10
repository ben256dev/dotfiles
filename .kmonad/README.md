# Keyboard: Colemak-DH with KMonad

[KMonad](https://github.com/kmonad/kmonad) remaps the laptop keyboard before anything else sees it, so this layout works everywhere: the login console, X, every app. The keys don't move; only what they type changes. Whenever kmonad isn't running, the keyboard is plain QWERTY.

## At a glance

- **Letters** are Colemak-DH.
- **Modifiers are on the home row.** Tap these keys for their letter, hold them for a modifier:

  | Hold for | Win | Alt | Ctrl | Shift |
  |---|---|---|---|---|
  | Left hand | `a` | `r` | `s` | `t` |
  | Right hand | `o` | `i` | `e` | `n` |

- **Hold either Alt** for digits, symbols and F-keys (the num layer). The digits are on the home row.
- **Hold either Shift** for arrows and paging (the nav layer). The arrows are on `m` `n` `e` `i`, the same direction keys bspwm, tmux and nvim use. Space there is Ctrl+Backspace, which deletes a word.
- **Backspace** is the key right of `'` (QWERTY's `[` key).
- **Caps Lock** is Esc.
- **The number row** types `! @ # $ % ^ & * ( )`. Digits come from the num layer.
- **The physical Shift, Ctrl and Alt keys aren't modifiers.** Shift and Alt hold layers (above). The Ctrl keys and the old Backspace key are `[def]`: "switch to the base layer", which you're already on, so in practice they do nothing.
- **Right Alt + Left Win** switches to plain QWERTY (for someone else, or games), and the same chord switches back.

## Layers

Each cell is a physical key, laid out like the laptop keyboard. The bottom row is Ctrl, Win, Alt, Space, Alt, Ctrl.

- `·`: same as the base layer
- `[num]` / `[nav]`: hold for that layer
- `hold`: the key you're holding to get this layer
- `[def]`: switch to the base layer

### Base layer

```
Esc   F1    F2    F3    F4    F5    F6    F7    F8    F9    F10   F11   F12
`     !     @     #     $     %     ^     &     *     (     )     -     =     [def]
Tab   q     w     f     p     b     j     l     u     y     '     Bksp  ]     \
Esc   a     r     s     t     g     m     n     e     i     o     ;     Enter
[nav] x     c     d     v     z     k     h     ,     .     /     [nav]
[def] Win   [num]             Space             [num] [def]
```

### Num layer: hold Left Alt or Right Alt

```
·     ·     ·     ·     ·     ·     ·     ·     ·     ·     ·     ·     ·
·     F1    F2    F3    A-F4  F5    F6    F7    F8    F9    F10   F11   F12   ·
·     !     @     #     $     %     ^     &     *     (     )     ·     ·     ·
-     1     2     3     4     5     6     7     8     9     0     ·     ·
·     [     ]     +     {     }     ·     =     ·     ·     ·     [def]
[def] [def] hold              _                 hold  [def]
```

Digits on the home row, `-` on Caps Lock, `_` on Space. `A-F4` is Alt+F4.

### Nav layer: hold Left Shift or Right Shift

```
·     ·     ·     ·     ·     ·     ·     ·     ·     ·     ·     ·     ·
·     ·     ·     ·     ·     ·     ·     ·     ·     ·     ·     ·     ·     ·
·     ·     ·     ·     ·     ·     ·     ·     PgUp  ·     ·     ·     ·     ·
·     ·     ·     ·     ·     ·     ←     ↓     ↑     →     ·     ·     ·
hold  ·     ·     PgDn  ·     ·     ·     ·     ·     ·     ·     hold
·     ·     ·                 ^Bksp             [num] ·
```

Arrows on `m` `n` `e` `i`, PgUp on `u`, PgDn on `d`. `^Bksp` is Ctrl+Backspace (delete a word).

### QWERTY layer: Right Alt + Left Win

Plain QWERTY with no home-row mods or layers: every key types what's printed on it, including Ctrl, Shift and Backspace. Hold Right Alt and tap Left Win to switch to it; the same chord switches back. Left Win on its own is a normal Win key in both layouts.

## Setup

`install.sh` sets this up. To set it up again, for example after changing keyboards:

```bash
~/dotfiles/.kmonad/setup.sh
```

It installs kmonad 0.4.3 to `/usr/local/bin` and adds the boot service `keyboard_mylaptop`, which runs kmonad on `~/.kmonad/colemakdh.kbd` from boot, before you log in.

### Using a different keyboard

The config remaps one keyboard, named on the `input` line at the top of `colemakdh.kbd`:

```
input (device-file "/dev/input/by-path/platform-i8042-serio-0-event-kbd")
```

That's the built-in keyboard on most laptops. To find yours, list the keyboards:

```bash
ls /dev/input/by-id/*-kbd /dev/input/by-path/*-kbd
```

- **External keyboard:** use its `by-id` path, for example `/dev/input/by-id/usb-Logitech_USB_Keyboard-event-kbd`. It's named after the keyboard, so it works in any USB port. If the keyboard shows up twice, use the entry without `-if01`.
- **Built-in keyboard:** use its `by-path` path. Those describe where a keyboard is connected, which never changes for a built-in one (and built-in keyboards usually have no `by-id` entry).

Put the path on the `input` line and run `~/dotfiles/.kmonad/setup.sh` again. It won't turn the service on if that path doesn't exist.

## Everyday commands

```bash
# Check an edited config for mistakes
kmonad --dry-run ~/.kmonad/colemakdh.kbd

# Apply config edits
sudo systemctl restart keyboard_mylaptop.service

# Is it running? If not, why?
systemctl status keyboard_mylaptop.service
journalctl -u keyboard_mylaptop.service -f

# Turn it off (plain QWERTY) or back on, now and at boot
sudo systemctl disable --now keyboard_mylaptop.service
sudo systemctl enable --now keyboard_mylaptop.service
```

If an edit breaks the config, kmonad won't start and the keyboard is plain QWERTY until you fix it and restart.
