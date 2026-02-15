#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KO="$SCRIPT_DIR/react_driver.ko"
TARGET="${TARGET:-root@192.168.1.130}"
REMOTE_PATH="${REMOTE_PATH:-/tmp/react_driver.ko}"

if [ ! -f "$KO" ]; then
  echo "Error: $KO not found. Build first (./rebuild.sh)."
  exit 1
fi

echo "Transferring $KO to $TARGET:$REMOTE_PATH"
cat "$KO" | ssh "$TARGET" "cat > '$REMOTE_PATH'"

echo "Transfer complete: $KO -> $TARGET:$REMOTE_PATH"
echo "Run ./install.sh to install the module on the target (or set TARGET/REMOTE_PATH env vars)."
