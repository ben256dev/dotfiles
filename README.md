# Dotfiles

## Install

This `install.sh` is meant to be run on a minimal Debian install.

During the installer’s “Software selection (tasksel)” screen:
- leave **standard system utilities** checked
- optionally check **SSH server**
- uncheck **Debian desktop environment** (and any specific DE like **GNOME**)

After first login, run:

```bash
wget -qO- https://ben256.com/install.sh | bash
```

## Preseeded ISO

This repo includes a ``preseed.cfg`` and a script to build a custom Debian netinst ISO that applies it.
Fork and edit ``preseed.cfg`` to match your preferences, then build the ISO:

Building the ISO

Install dependencies:

```bash
sudo apt update
sudo apt install xorriso isolinux syslinux-common
```

Build:

```bash
./build_iso.sh <debian-netinst.iso>
```
