#!/bin/sh

set -e

export BR2_DL_DIR="${HOME}/.dl"

git submodule init
git submodule sync
git submodule update --recursive

make -C buildroot BR2_EXTERNAL=../buildroot-external rpi4_buildroot_config

make -C buildroot BR2_EXTERNAL=../buildroot-external

echo "Build complete."
echo "Images available in buildroot/output/images/"