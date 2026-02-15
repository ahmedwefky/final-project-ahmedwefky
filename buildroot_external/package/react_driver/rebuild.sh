#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDROOT_PATH="/home/ahmed/repos/final-project-ahmedwefky/buildroot"
KDIR="${BUILDROOT_PATH}/output/build/linux-custom"
CROSS_COMPILE="${BUILDROOT_PATH}/output/host/bin/arm-linux-"

echo "Cleaning..."
cd "$SCRIPT_DIR"
rm -f react_driver.ko react_driver.o .react_driver.o.cmd modules.order Module.symvers

echo "Building ARM module..."
KDIR="$KDIR" \
ARCH=arm \
CROSS_COMPILE="$CROSS_COMPILE" \
make

echo "Verifying module format..."
file react_driver.ko

echo "Build complete!"
