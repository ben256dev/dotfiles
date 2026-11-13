# Dotfiles

![Ben256 dotfiles install script](https://shthub.org/u/benjamin/ben256_install.png?raw)

## Install

This `install.sh` is meant to be run on a minimal Debian install.

On the installer’s “Set up users and passwords” screen, leave the **root password** blank. Debian then installs `sudo` and adds your user to the sudo group, which `install.sh` needs.

During the installer’s “Software selection (tasksel)” screen:
- leave **standard system utilities** checked
- optionally check **SSH server**
- uncheck **Debian desktop environment** (and any specific DE like **GNOME**)

After first login, run:

```bash
wget -qO- https://ben256.com/install.sh | bash
```

## Preseeded ISO

This repo includes a `preseed.cfg` and a script to build a custom Debian netinst ISO that applies it.

**Warning:** the preseeded installer erases the install disk without asking for confirmation. Only boot it on a machine you mean to wipe.

Fork and edit `preseed.cfg` to match your preferences, then build the ISO:

### Building the ISO

Install dependencies:

```bash
sudo apt update
sudo apt install xorriso isolinux syslinux-common
```

Build:

```bash
./build_iso.sh <debian-netinst.iso>
```

## Usage

### v

`v` command is used as a wrapper for nvim. Use it to open one or more files, quit them with `:wq` / `:wqa`, and resume them quickly with `v -`. `v` automatically fuzzy-picks files in the tree of the current directory, so no need to leave the base directory of your git repo, and you can open files without typing the full name of the file. Forget `ctrl+z` and `fg` workflow, and use `v` to its full potential to quickly switch between the terminal and text editor. Run `v -h` for more info.

### kmonad / Colemak-DH

The entire keyboard is rebound from QWERTY layout to Colemak-DH, with home-row mods and a layer for numbers and symbols, so leaving the home-row becomes unnecessary except for `~` and `` ` ``. `install.sh` turns it on, so after installing, the keyboard is Colemak-DH; Right Alt + Left Win switches to QWERTY and back. Everything else is in `.kmonad/README.md`.

### Neovim

The changes to Neovim are for the most part minimal. There is a reminder in the bottom right that typing `Space ?` brings you to an editable `CHEATSHEET.md` with most of the important additions.

## Migration

```bash
./install.sh --migrate   # Install on an existing system
./install.sh --dry-run   # Preview config links
./install.sh --apply     # Apply config only
```

Backups: `~/.local/state/dotfiles/backups/`; `latest` contains the last backup path.
Restore with `./scripts/rollback BACKUP_DIRECTORY`.
Package logs: `~/.local/state/dotfiles/logs/`.

Machine settings: `.config/dotfiles/machine.sh` (monitor layout and keyboard device).
Local shell additions: `~/.local_aliases`.

`FIREFOX_GTK_PREFIX` selects Firefox's GTK build. `scripts/setup-gtk3` builds
GTK 3.24.52 under `~/.local/opt` with the X11 border fix. The Firefox launcher
uses it; other applications keep Debian's GTK.

### Wallpaper

Choose **Wallpaper** in rofi, or run `wallpaper default` / `wallpaper nebula`.
The selection persists across sessions.

### Window shortcuts

- Super+Return: new Ghostty terminal; Super+Space: rofi launcher.
- Alt+1 / Alt+2: focus the last used Ghostty / Firefox window, or launch one.
- Super+Tab: toggle tiled/monocle; Super+C / Super+Shift+C: cycle windows.
- Super+backtick: previous window; Super+1 through Super+0: desktops 1–10.
- Super+M/N/E/I: focus left/down/up/right (Colemak-DH); add Shift to move.

With kmonad, the physical Alt keys select the number layer. Use the home-row
Alt modifier plus a number from that layer for Alt+1/2. Right Alt+Left Win toggles
plain QWERTY.
