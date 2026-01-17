#!/bin/sh

set -e

export BR2_DL_DIR="${HOME}/.dl"

git submodule init
git submodule sync
git submodule update --recursive

if [ ! -e buildroot/.config ]
then
	echo "MISSING BUILDROOT CONFIGURATION FILE"

	if [ -e ../buildroot_external/configs/rpi4_buildroot_config ]
	then
		echo "USING rpi4_buildroot_config"
		make -C buildroot defconfig BR2_EXTERNAL=../buildroot_external BR2_DEFCONFIG=../buildroot_external/configs/rpi4_buildroot_config
	else
		echo "Run ./save_config.sh to save this as the default configuration"
		echo "Then add packages as needed to complete the installation, re-running ./save_config.sh as needed"
		make -C buildroot defconfig BR2_EXTERNAL=../buildroot_external BR2_DEFCONFIG=../buildroot_external/configs/rpi4_buildroot_config
	fi
else
	echo "USING EXISTING BUILDROOT CONFIG"
	make -C buildroot BR2_EXTERNAL=../buildroot_external
fi

echo "Build complete."
echo "Images available in buildroot/output/images/"