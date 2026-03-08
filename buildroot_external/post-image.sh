#!/bin/bash

set -e

BOARD_DIR="$(dirname $0)"
GENIMAGE_CFG="${BOARD_DIR}/configs/genimage.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

# 1. Clear out any old genimage artifacts
rm -rf "${GENIMAGE_TMP}"

# 2. Execute genimage to create the SD card image
genimage \
    --rootpath "${TARGET_DIR}" \
    --tmppath "${GENIMAGE_TMP}" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"

exit $?