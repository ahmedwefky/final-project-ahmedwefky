# A/B OTA Update Guide

This document explains the A/B (dual-partition) update strategy implemented for the Raspberry Pi 4. This strategy provides safe, atomic firmware updates with zero downtime and instant rollback capability.

## Architecture

The system utilizes a dual-root-partition layout on the SD card to ensure that a working system is always available.

### Partition Layout

1.  **/dev/mmcblk0p1 (FAT32)**: The Boot partition. It contains the U-Boot bootloader, Linux kernel (`Image`), and device tree blobs. This partition is shared by both root filesystems.
2.  **/dev/mmcblk0p2 (ext4)**: Root filesystem A.
3.  **/dev/mmcblk0p3 (ext4)**: Root filesystem B.
4.  **/dev/mmcblk0p4 (ext4)**: Persistent Data partition (optional, used for logs and user settings).

### Boot Logic

U-Boot manages the boot process using the `bootpart` environment variable:
*   If `bootpart=2`, the system boots from Partition 2.
*   If `bootpart=3`, the system boots from Partition 3.

## Update Workflow

The A/B strategy allows the device to continue running on the active partition while the update is written to the inactive "shadow" partition.

1.  **Preparation**: The build machine generates a signed SWUpdate package (`.swu`) containing the new root filesystem.
2.  **Deployment**: The package is transferred to the device.
3.  **Installation**: SWUpdate identifies the inactive partition (e.g., if Partition 2 is active, Partition 3 is the target) and streams the new filesystem into it.
4.  **Activation**: A post-update hook modifies the U-Boot environment to set the `bootpart` variable to the newly updated partition.
5.  **Completion**: Upon reboot, the device starts from the new partition.

## Execution Steps

### 1. Create the Update Package (Build Machine)

Run the creation script providing a version number and the path to your generated `rootfs.ext4`:

```bash
cd ota_updates/
./create_ab_update.sh 1.1.0 ../buildroot/output/images/rootfs.ext4
```

### 2. Transfer the Package

Use `scp` to move the generated `.swu` file to the device:

```bash
scp update-ab-1.1.0.swu root@<device-ip>:/tmp/
```

### 3. Apply the Update (Device)

Execute `swupdate` to install the image. The pre-update hooks will automatically handle partition targeting.

```bash
swupdate -i /tmp/update-ab-1.1.0.swu
reboot
```

## Partition Management

You can query the system state or manually trigger a rollback using the provided tools on the device.

### Check Update Status

To see which partition is active and which is the current update target:

```bash
/root/ab_partition_manager.sh status
```

### Manual Rollback

If you need to revert to the previous version after an update, toggle the boot partition back using the partition manager:

```bash
/root/ab_partition_manager.sh rollback
reboot
```

## Key U-Boot Variables

| Variable | Purpose |
| :--- | :--- |
| `bootpart` | Defines the active root partition (2 or 3). |
| `upgrade_available` | Flag used to indicate a pending trial boot of a new version. |
| `bootcount` | Incremented by U-Boot to detect boot failures for automatic rollback. |