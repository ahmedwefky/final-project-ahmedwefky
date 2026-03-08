#!/bin/sh

set -e

cd buildroot

if [ -d "output" ]; then
    echo "Removing stale output directory..."
    rm -rf output
fi

make distclean
echo "Clean complete."