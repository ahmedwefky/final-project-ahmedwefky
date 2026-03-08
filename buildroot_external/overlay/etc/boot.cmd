# Default bootpart to 2 if not set
if test -z "${bootpart}"; then
    setenv bootpart 2
    saveenv
fi

echo "Booting from partition ${bootpart}..."

# Set kernel boot arguments
# rootwait is essential for SD cards to ensure the device is ready
setenv bootargs "console=ttyS0,115200 console=tty1 root=/dev/mmcblk0p${bootpart} rootwait rootfstype=ext4 rw"

# Load the kernel and Device Tree from the boot partition (FAT, 0:1)
# Note: Standard Buildroot RPi builds put Image/DTB in the FAT partition, not rootfs.
load mmc 0:1 ${kernel_addr_r} Image
load mmc 0:1 ${fdt_addr_r} bcm2711-rpi-4-b.dtb

# Boot the kernel (using booti for ARM64 uncompressed kernel)
booti ${kernel_addr_r} - ${fdt_addr_r}