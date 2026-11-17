#!/bin/bash
set -euo pipefail

fail() { echo "$1" >&2; exit 1; }

[ "$#" -eq 1 ] || fail "Usage: $0 <debian-netinst.iso>"

ISO="$1"
OUTPUT="debian-preseed.iso"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MBR=/usr/lib/ISOLINUX/isohdpfx.bin
PRESEED_ARGS="auto=true file=/cdrom/preseed.cfg"

[ -f "$ISO" ] || fail "No such file: $ISO"
command -v xorriso >/dev/null || fail "Missing xorriso (sudo apt install xorriso)"
command -v openssl >/dev/null || fail "Missing openssl (sudo apt install openssl)"
[ -f "$MBR" ] || fail "Missing $MBR (sudo apt install isolinux)"

# Naming the disk makes the install fully unattended. Leaving it empty makes
# the installer list the disks and ask, which is safer when the target machine
# has more than one (a USB stick counts) or you don't know its disk names.
echo "Disks on this machine (only relevant if you'll install on this machine):"
lsblk -dno NAME,SIZE,MODEL -e 7 | sed 's/^/  /'
read -rp "Disk to erase, e.g. nvme0n1 (empty = choose during install): " disk
disk="${disk#/dev/}"
if [ -z "$disk" ]; then
    DISK_LINE="# Install disk: chosen during installation"
elif [[ "$disk" =~ ^[a-z0-9]+$ ]]; then
    DISK_LINE="d-i partman-auto/disk string /dev/$disk"
else
    fail "Not a disk name: $disk"
fi

read -rp "Hostname for the new machine (empty = debian): " hostname
hostname="${hostname:-debian}"
[[ "$hostname" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || fail "Not a hostname: $hostname"
HOSTNAME_LINES="d-i netcfg/get_hostname string $hostname
d-i netcfg/hostname string $hostname"

# The repo's preseed.cfg holds no password. Only a hash of the one typed here
# goes into the ISO.
read -rsp "Password for the new user: " password; echo
read -rsp "Repeat password: " password_again; echo
[ -n "$password" ] || fail "Password cannot be empty"
[ "$password" = "$password_again" ] || fail "Passwords do not match"
PASSWORD_HASH="$(printf '%s' "$password" | openssl passwd -6 -stdin)"
unset password password_again

WORKDIR="$(mktemp -d)"
trap 'rm -rf -- "$WORKDIR"' EXIT

echo "Extracting ISO..."
xorriso -osirrox on -indev "$ISO" -extract / "$WORKDIR"
chmod -R u+w "$WORKDIR"

echo "Injecting preseed.cfg..."
grep -q '__PASSWORD_HASH__' "$SCRIPT_DIR/preseed.cfg" || fail "preseed.cfg has no __PASSWORD_HASH__ placeholder"
for placeholder in __INSTALL_DISK__ __HOSTNAME__; do
    grep -q "^# $placeholder\$" "$SCRIPT_DIR/preseed.cfg" || fail "preseed.cfg has no '# $placeholder' placeholder"
done
# awk reads the values from the environment, so nothing in them needs escaping.
PASSWORD_HASH="$PASSWORD_HASH" DISK_LINE="$DISK_LINE" HOSTNAME_LINES="$HOSTNAME_LINES" \
awk '
    $0 == "# __INSTALL_DISK__" { print ENVIRON["DISK_LINE"]; next }
    $0 == "# __HOSTNAME__"     { print ENVIRON["HOSTNAME_LINES"]; next }
    { i = index($0, "__PASSWORD_HASH__")
      if (i) $0 = substr($0, 1, i - 1) ENVIRON["PASSWORD_HASH"] substr($0, i + 17)
      print }
' "$SCRIPT_DIR/preseed.cfg" > "$WORKDIR/preseed.cfg"

echo "Updating boot configs..."
# Add the preseed to every install entry (not rescue mode). Fail loudly if
# Debian changes its menus, rather than silently building an ISO that
# doesn't preseed.
patch_boot_cfg() {
    local cfg="$WORKDIR/$1"
    grep -q -- '--- quiet' "$cfg" 2>/dev/null || fail "No '--- quiet' boot line in $1; Debian may have changed its boot menus"
    sed -i "/rescue\/enable/!s|--- quiet|--- quiet $PRESEED_ARGS|" "$cfg"
}
patch_boot_cfg boot/grub/grub.cfg   # UEFI
patch_boot_cfg isolinux/txt.cfg     # BIOS "Install"
patch_boot_cfg isolinux/gtk.cfg     # BIOS "Graphical install" (the default entry)

echo "Rebuilding ISO..."
xorriso -as mkisofs \
    -o "$OUTPUT" \
    -isohybrid-mbr "$MBR" \
    -c isolinux/boot.cat \
    -b isolinux/isolinux.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot -isohybrid-gpt-basdat \
    "$WORKDIR"

if [ -n "$disk" ]; then
    echo "Done: $OUTPUT (erases /dev/$disk without asking)"
else
    echo "Done: $OUTPUT (asks which disk to erase)"
fi
