#!/bin/bash
# Wrapper post-build script that runs both default and custom build steps
# This allows us to extend the default buildroot post-build script

set -e

TARGET_DIR=$1

# Run the default buildroot post-build script if it exists
if [ -x "board/raspberrypi4/post-build.sh" ]; then
    echo "INFO: Running default buildroot post-build script..."
    ./board/raspberrypi4/post-build.sh "$TARGET_DIR"
fi

# Run our custom post-build script for A/B OTA specific setup
CUSTOM_POST_SCRIPT="$(dirname "$0")/post-build.sh"
if [ -x "$CUSTOM_POST_SCRIPT" ]; then
    echo "INFO: Running custom A/B OTA post-build script..."
    "$CUSTOM_POST_SCRIPT" "$TARGET_DIR"
fi

exit 0
