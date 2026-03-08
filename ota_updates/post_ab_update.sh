#!/bin/sh
# Post-update hook for A/B partition strategy
# This script runs AFTER successful image installation
# - Toggles next boot partition
# - Sets upgrade available flag

set -e

# Run only during post-install phase
if [ "$1" != "postinst" ]; then
    exit 0
fi

echo "=== A/B Post-Update Configuration ==="

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
    echo "ERROR: U-Boot tools not found"
    exit 1
fi

# Get current active partition
ACTIVE_PART=$($FW_GETENV bootpart 2>/dev/null || echo "2")
if [ -z "$ACTIVE_PART" ]; then
    ACTIVE_PART=2
fi

# Set next boot partition to the updated one (opposite of current)
if [ "$ACTIVE_PART" = "2" ]; then
    NEXT_PART=3
else
    NEXT_PART=2
fi

echo "Current active partition: $ACTIVE_PART"
echo "Setting next boot partition: $NEXT_PART"

# Set the next boot partition
$FW_SETENV bootpart "$NEXT_PART" || {
    echo "ERROR: Failed to set next boot partition"
    exit 1
}

# Keep upgrade flag set (will be cleared on successful boot)
echo "Upgrade available flag: ON (will be cleared on successful boot)"
$FW_SETENV upgrade_available 1 || true

# Save NEXT_PART for potential rollback or diagnosis
$FW_SETENV upgrade_partition "$NEXT_PART" || true

echo "Post-update configuration: SUCCESS"
echo "Device will boot from partition $NEXT_PART after reboot"
exit 0
