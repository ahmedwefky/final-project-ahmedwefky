#!/bin/sh

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

if [ ! -e buildroot/output/images/sdcard.img ]; then
    echo "Error: Image not found."
    exit 1
fi

if [ $# -ne 1 ]; then
    echo "Usage: sudo $0 /dev/sdX"
    echo
    echo "Available removable devices:"
    lsblk -o NAME,SIZE,TYPE,MODEL | grep disk
    exit 1
fi

DEVICE="$1"

if [ ! -b "$DEVICE" ]; then
    echo "Error: Device not found or not a block device: $DEVICE"
    exit 1
fi

# Prevent flashing system disk
ROOT_DEV=$(lsblk -no PKNAME "$(df / | tail -1 | awk '{print $1}')")
if [ "$DEVICE" == "/dev/$ROOT_DEV" ]; then
    echo "Error: Refusing to overwrite system disk ($DEVICE)"
    exit 1
fi

echo "--------------------------------------------------"
echo "Image  : buildroot/output/images/sdcard.img"
echo "Target : $DEVICE"
echo "--------------------------------------------------"
lsblk "$DEVICE"
echo
read -rp "Type 'FLASH' to continue: " CONFIRM
if [ "$CONFIRM" != "FLASH" ]; then
    echo "Flash cancelled."
    exit 1
fi

# -------- Flash --------
echo "Unmounting partitions..."
umount "${DEVICE}"* 2>/dev/null || true

echo "Flashing image (this may take a few minutes)..."
dd if=buildroot/output/images/sdcard.img of="$DEVICE" bs=4M status=progress conv=fsync

sync

echo
echo "Flash complete!"
echo "You can now safely remove the SD card."