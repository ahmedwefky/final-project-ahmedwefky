#!/bin/sh
# Pre-update hook for A/B partition strategy
# This script runs BEFORE image installation
# - Verifies target partition availability
# - Prepares system for update

set -e

# Run only during pre-install phase
if [ "$1" != "preinst" ]; then
    exit 0
fi

echo "=== A/B Pre-Update Checks ==="

# Find U-Boot tools (handle different installation paths)
find_uboot_tool() {
    local tool=$1
    if [ -x "/usr/sbin/$tool" ]; then echo "/usr/sbin/$tool"; return 0; fi
    if [ -x "/usr/bin/$tool" ]; then echo "/usr/bin/$tool"; return 0; fi
    if [ -x "/sbin/$tool" ]; then echo "/sbin/$tool"; return 0; fi
    if command -v "$tool" >/dev/null 2>&1; then command -v "$tool"; return 0; fi
    return 1
}

FW_SETENV=$(find_uboot_tool fw_setenv || true)
FW_GETENV=$(find_uboot_tool fw_getenv || true)

# Fallback: If fw_setenv/fw_getenv are missing, try finding fw_printenv and creating symlinks
if [ -z "$FW_SETENV" ] || [ -z "$FW_GETENV" ]; then
    FW_PRINTENV=$(find_uboot_tool fw_printenv || true)
    if [ -n "$FW_PRINTENV" ]; then
        mkdir -p /tmp/uboot-tools
        ln -sf "$FW_PRINTENV" /tmp/uboot-tools/fw_setenv
        ln -sf "$FW_PRINTENV" /tmp/uboot-tools/fw_getenv
        FW_SETENV="/tmp/uboot-tools/fw_setenv"
        FW_GETENV="/tmp/uboot-tools/fw_getenv"
    fi
fi

if [ -z "$FW_SETENV" ] || [ -z "$FW_GETENV" ]; then
    echo "ERROR: U-Boot tools (fw_setenv/fw_getenv) not found. Check u-boot-tools package."
    exit 1
fi

# Remount boot partition as read-write to allow environment updates
echo "Remounting /boot as read-write..."
mount -o remount,rw /boot

# Get current active partition
ACTIVE_PART=$($FW_GETENV bootpart 2>/dev/null || echo "2")
if [ -z "$ACTIVE_PART" ]; then
    ACTIVE_PART=2
fi

# Determine target partition (inactive one)
if [ "$ACTIVE_PART" = "2" ]; then
    TARGET_PART=3
else
    TARGET_PART=2
fi

echo "Active partition: $ACTIVE_PART"
echo "Target partition (will be updated): $TARGET_PART"

# Verify target partition device exists
TARGET_DEVICE="/dev/mmcblk0p$TARGET_PART"
if [ ! -b "$TARGET_DEVICE" ]; then
    echo "ERROR: Target device not found: $TARGET_DEVICE"
    exit 1
fi

# Inform SWUpdate about the correct target device.
# This overrides the placeholder value in sw-description.
echo "SWUPDATE_IMAGES_rootfs.ext4_DEVICE=$TARGET_DEVICE"
echo "Target device for SWUpdate set to: $TARGET_DEVICE"

# Verify target partition is writable
if [ ! -w "$TARGET_DEVICE" ]; then
    echo "ERROR: Target partition not writable: $TARGET_DEVICE"
    exit 1
fi

echo "Target partition writable: PASS"

# Set upgrade flag in U-Boot environment
echo "Setting upgrade flag..."
$FW_SETENV upgrade_available 1 2>/dev/null || $FW_SETENV upgrade_available 1 || {
    echo "WARNING: Could not set upgrade flag"
}

# Reset bootcount for rollback detection
echo "Resetting bootcount..."
$FW_SETENV bootcount 0 || {
    echo "WARNING: Could not reset bootcount"
}

# Ensure data is flushed and remount /boot as read-only for safety
sync
mount -o remount,ro /boot
echo "Remounted /boot as read-only"

# Stop services that might interfere with root filesystem update
echo "Stopping services..."
if [ -x "/etc/init.d/S99swupdate" ]; then
    /etc/init.d/S99swupdate stop || true
fi

# Drop caches to minimize memory pressure during update
sync
echo 1 > /proc/sys/vm/drop_caches || true

echo "Pre-update checks: SUCCESS"
exit 0
