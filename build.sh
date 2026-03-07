#!/bin/sh

set -e

export BR2_DL_DIR="${HOME}/.buildroot_dl"
export BR2_CCACHE_DIR="${HOME}/.buildroot-ccache"

git submodule init
git submodule sync
git submodule update --recursive

if [ ! -e buildroot/.config ]
then
	echo "\nMISSING BUILDROOT CONFIGURATION FILE\n"

	if [ -e buildroot_external/configs/rpi4_buildroot_config ]
	then
		echo "\nUsing existing rpi4_buildroot_config\n"
		make -C buildroot defconfig BR2_EXTERNAL=../buildroot_external BR2_DEFCONFIG=../buildroot_external/configs/rpi4_buildroot_config
		echo "\nRun this script again to build the image\n"
	else
		echo "Run ./save_config.sh to save this as the default configuration"
		echo "Then add packages as needed to complete the installation, re-running ./save_config.sh as needed"
		make -C buildroot defconfig BR2_EXTERNAL=../buildroot_external BR2_DEFCONFIG=../buildroot_external/configs/rpi4_buildroot_config
	fi
else
	echo "\nUSING EXISTING BUILDROOT CONFIG\n"
	START_TIME=$(date +%s)
	make -C buildroot BR2_EXTERNAL=../buildroot_external -j$(nproc) -l$(nproc)
	END_TIME=$(date +%s)
	ELAPSED=$((END_TIME - START_TIME))
	echo "\nBuild complete."
	echo "\nBuild took $(($ELAPSED / 60))m $(($ELAPSED % 60))s"
	echo "\nImage available in buildroot/output/images/"
fi