#!/bin/bash
# Post-build script for A/B OTA update system
# This script runs after the rootfs is built but before image creation
# It compiles boot.cmd to boot.scr for U-Boot

set -e

TARGET_DIR=$1
# Use mkimage from HOST_DIR/bin (standard Buildroot location)
MKIMAGE="${HOST_DIR}/bin/mkimage"
BOOT_SCR_TARGET="${BINARIES_DIR}/boot.scr"
# Use absolute path relative to this script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOT_CMD_SOURCE="${SCRIPT_DIR}/overlay/etc/boot.cmd"

echo -e "Post-build: Compiling boot.cmd to boot.scr"

if [ -f "${BOOT_CMD_SOURCE}" ]; then    
    echo -e "Found boot.cmd, compiling to boot.scr"
    
    # Compile boot.cmd to boot.scr
    ${MKIMAGE} -c none -A arm -T script -d "${BOOT_CMD_SOURCE}" "${BOOT_SCR_TARGET}"
    
    if [ -f "${BOOT_SCR_TARGET}" ]; then
        echo -e "boot.scr created successfully"
    else
        echo "ERROR: Failed to create boot.scr"
        exit 1
    fi
else
    echo "WARNING: boot.cmd not found at ${BOOT_CMD_SOURCE}"
fi

# Copy boot configuration files to the images directory. This makes the genimage
# configuration more robust by removing fragile relative paths.
echo "Copying config_0w.txt and cmdline.txt to ${BINARIES_DIR}"
cp "${SCRIPT_DIR}/configs/config_0w.txt" "${BINARIES_DIR}/config_0w.txt"
cp "${SCRIPT_DIR}/configs/cmdline.txt" "${BINARIES_DIR}/cmdline.txt"

# Setup fstab to mount the boot partition at /boot
# This is required for fw_setenv to modify uboot.env
if ! grep -q "/boot" "${TARGET_DIR}/etc/fstab"; then
    echo "/dev/mmcblk0p1 /boot vfat ro 0 0" >> "${TARGET_DIR}/etc/fstab"
fi

# Ensure /boot directory exists in the rootfs
mkdir -p "${TARGET_DIR}/boot"

# Ensure WiFi credentials are provided via environment variables
if [ -z "${WIFI_SSID}" ] || [ -z "${WIFI_PSK}" ]; then
    echo "ERROR: WIFI_SSID or WIFI_PSK environment variables are not set."
    echo "Usage: WIFI_SSID='MyNetwork' WIFI_PSK='MyPassword' make"
    exit 1
fi

WPA_CONF="${TARGET_DIR}/etc/wpa_supplicant/wpa_supplicant.conf"
if [ -f "$WPA_CONF" ]; then
    echo "Post-build: Injecting WiFi credentials into target"
    # Use | as a delimiter for sed to handle special characters in SSID/PSK
    sed -i "s|\${WIFI_SSID}|${WIFI_SSID}|g" "$WPA_CONF"
    sed -i "s|\${WIFI_PSK}|${WIFI_PSK}|g" "$WPA_CONF"
fi

echo -e "Post-build script completed"
exit 0
