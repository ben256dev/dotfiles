#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <debian-netinst.iso>"
    exit 1
fi

ISO="$1"
WORKDIR=$(mktemp -d)
OUTPUT="debian-preseed.iso"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

echo "Extracting ISO..."
xorriso -osirrox on -indev "$ISO" -extract / "$WORKDIR"
chmod -R u+w "$WORKDIR"

echo "Injecting preseed.cfg..."
cp "$SCRIPT_DIR/preseed.cfg" "$WORKDIR/preseed.cfg"

echo "Updating boot configs..."
sed -i 's|--- quiet|--- quiet auto=true file=/cdrom/preseed.cfg|' "$WORKDIR/boot/grub/grub.cfg"
sed -i 's|--- quiet|--- quiet auto=true file=/cdrom/preseed.cfg|' "$WORKDIR/isolinux/txt.cfg"

echo "Rebuilding ISO..."
xorriso -as mkisofs \
    -o "$OUTPUT" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -c isolinux/boot.cat \
    -b isolinux/isolinux.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot -isohybrid-gpt-basdat \
    "$WORKDIR"

echo "Done: $OUTPUT"
