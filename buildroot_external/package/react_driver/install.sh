#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${TARGET:-root@192.168.1.130}"
REMOTE_PATH="${REMOTE_PATH:-/tmp/react_driver.ko}"

echo "Installing module on target ($TARGET)"
ssh "$TARGET" "set -e; rmmod react_driver 2>/dev/null || true; insmod '$REMOTE_PATH' && echo 'insmod succeeded' || (echo 'insmod failed'; dmesg | tail -20; exit 1)"

echo "Install step complete. Check target dmesg for messages."
