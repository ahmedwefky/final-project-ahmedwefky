#!/bin/sh

set -e

export BR2_DL_DIR="${HOME}/.buildroot_dl"
export BR2_CCACHE_DIR="${HOME}/.buildroot-ccache"

git submodule init
git submodule sync
git submodule update --recursive

# Function to start the build process
build_image() 
{
	START_TIME=$(date +%s)
	make -C buildroot BR2_EXTERNAL=../buildroot_external -j$(nproc) -l$(nproc)
	END_TIME=$(date +%s)
	ELAPSED=$((END_TIME - START_TIME))
	echo "\nBuild complete."
	echo "\nBuild took $(($ELAPSED / 60))m $(($ELAPSED % 60))s"
	echo "\nImage available in buildroot/output/images/"
}

if [ ! -e buildroot/.config ]
then
	echo "\nMISSING BUILDROOT CONFIGURATION FILE\n"
	if [ -e buildroot_external/configs/rpi0_buildroot_config ]
	then
		echo "\nUsing existing rpi0_buildroot_config\n"
	else
		echo "Warning: Config file not found in buildroot_external. Attempting to use default."
	fi
	make -C buildroot defconfig BR2_EXTERNAL=../buildroot_external BR2_DEFCONFIG=../buildroot_external/configs/rpi0_buildroot_config
	build_image
else
	echo "\nUSING EXISTING BUILDROOT CONFIG\n"
	build_image
fi