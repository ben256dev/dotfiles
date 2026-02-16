# KMonad Colemak-DH Configuration

KMonad config for a Colemak-DH layout with home row mods, navigation, and number layers.

## Layers

### Base Layer (Colemak-DH)

```
 _    F1   F2   F3   F4   F5   F6   F7   F8   F9   F10  F11  F12
 `    !    @    #    $    %    ^    &    *    (    )    -    =    [reset]
Tab   q    w    f    p    b    j    l    u    y    '   Bspc  ]    \
Esc   a    r    s    t    g    m    n    e    i    o    ;   Ret
[nav] x    c    d    v    z    k    h    ,    .    /   [nav]
[def] [qw] [num]         Spc       [num] [def]
```

- **Home row mods** (180ms tap-hold): `a`=Meta, `r`=Alt, `s`=Ctrl, `t`=Shift / `n`=Shift, `e`=Ctrl, `i`=RAlt, `o`=Meta
- **Hold `x`**: Ctrl+Backspace (delete word)
- **Number row** outputs shifted symbols (`!@#$%^&*()`) by default

### Num Layer (hold LAlt or RAlt)

```
 _    _    _    _    _    _    _    _    _    _    _    _    _
 _    F1   F2   F3  A-F4  F5   F6   F7   F8   F9  F10  F11  F12   _
 _    !    @    #    $    %    ^    &    *    (    )    _    _    _
 -    1    2    3    4    5    6    7    8    9    0    _    _
 _    [    ]    +    {    }    _    =    _    _    _   [def]
[def] [def] [def]         _        [num] [def]
```

- **Caps Lock position**: `-` (hyphen)
- **Space**: `_` (underscore)

### Nav Layer (hold LShift or RShift)

Vim-style arrows with navigation keys.

```
 _    _    _    _    _    _    _    _    _    _    _    _    _
 _    _    _    _    _    _    _    _    _    _    _    _    _    _
 _    _  C-Bspc _    _    _    _    _   PgUp  _    _    _    _    _
 _    _    _    _    _    _    <-  Down  Up   ->   _    _    _
 _    _    _   PgDn  _    _    _    _    _    _    _    _
 _    _    _             Bspc         [num]  _
```

- **Arrows**: vim-style on `hjkl` positions
- **`w` position**: Ctrl+Backspace (delete word)
- **`u` position**: Page Up
- **`d` position**: Page Down
- **Space**: Backspace

### QWERTY Layer (hold Win for 1s)

Plain QWERTY with no mods or layers. Hold Win for 1 second again to switch back to Colemak-DH.

## Systemd Service

The config runs as a systemd service that starts on boot (before login):

```
/etc/systemd/system/keyboard_mylaptop.service
```

### Common Commands

```bash
# Restart after config changes
sudo kill $(pgrep kmonad) && sudo systemctl restart keyboard_mylaptop.service

# Check status
systemctl status keyboard_mylaptop.service

# View logs
journalctl -u keyboard_mylaptop.service -f

# Enable/disable on boot
sudo systemctl enable keyboard_mylaptop.service
sudo systemctl disable keyboard_mylaptop.service
```

## Config File

- **Config**: `~/startup/colemakdh.kbd`
- **Binary**: `~/.local/bin/kmonad`
- **Device**: `/dev/input/by-path/platform-i8042-serio-0-event-kbd`
