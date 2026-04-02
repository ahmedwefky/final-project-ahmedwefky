#!/bin/sh
set -e

echo "Saving Buildroot config"
make -C buildroot savedefconfig BR2_DEFCONFIG=../buildroot_external/configs/rpi0_buildroot_config

echo "Saving Linux kernel config"
make -C buildroot linux-savedefconfig
cp buildroot/output/build/linux-*/defconfig buildroot_external/configs/rpi0_linux.config

echo "Configs saved."