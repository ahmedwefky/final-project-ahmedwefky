#!/bin/sh
# Verify A/B Update Strategy Setup
# Checks if all necessary components are in place

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Environment Detection
IS_PI=0
if [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model; then
    IS_PI=1
fi

echo "Detected Environment: $([ $IS_PI -eq 1 ] && echo "Raspberry Pi (Device)" || echo "Development Machine (Build)")"
PASSED=0
FAILED=0

check_pass() {
    echo -e "${GREEN}✓${NC}  $1"
    PASSED=$((PASSED + 1))
}

check_fail() {
    echo -e "${RED}✗${NC}  $1" >&2
    FAILED=$((FAILED + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

check_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

echo "=== A/B Update Strategy Verification ==="
echo ""

# ===== Build Machine Checks (if running this script) =====
if [ $IS_PI -eq 0 ]; then
    check_info "Build machine checks:"
    
    # Check for required scripts
    for f in create_ab_update.sh ab_partition_manager.sh pre_ab_update.sh post_ab_update.sh; do
        if [ -f "$f" ]; then
            check_pass "Script found: $f"
        else
            check_fail "Script missing: $f"
        fi
    done
    
    # Check for templates
    for f in "${HOME}/ota_key/private.pem" "public.pem"; do
        if [ -f "$f" ]; then
            check_pass "File found: $f"
        else
            check_fail "File missing: $f"
        fi
    done
    
else
    # ===== Device Checks =====
echo "Device-side checks:"

# Check if boot partition is mounted (needed for fw_env access)
if mountpoint -q /boot; then
    check_pass "/boot is mounted"
else
    check_fail "/boot is not mounted (required for U-Boot env access)"
fi

# Check fw_setenv/fw_getenv
if command -v fw_setenv > /dev/null 2>&1; then
    check_pass "fw_setenv available"
else
    check_fail "fw_setenv not found (need u-boot-tools)"
fi

if command -v fw_printenv > /dev/null 2>&1; then
    check_pass "fw_printenv available"
elif command -v fw_getenv > /dev/null 2>&1; then
    check_pass "fw_getenv available"
else
    check_fail "U-Boot environment read tool (fw_printenv or fw_getenv) not found"
fi

# Check fw_env.config
if [ -f "/etc/fw_env.config" ]; then
    check_pass "/etc/fw_env.config exists"
    check_info "Content:"
    cat /etc/fw_env.config | sed 's/^/    /'
else
    check_fail "/etc/fw_env.config not found"
fi

echo ""

# Check partitions
check_info "Partition configuration:"
for part in 2 3; do
    DEVICE="/dev/mmcblk0p$part"
    if [ -b "$DEVICE" ]; then
        SIZE=$(blockdev --getsz "$DEVICE" 2>/dev/null || echo "unknown")
        check_pass "Partition $part exists: $DEVICE ($SIZE sectors)"
    else
        check_fail "Partition $part missing: $DEVICE"
    fi
done

echo ""

# Check U-Boot variables
check_info "U-Boot environment variables:"

FW_GET=""
if command -v fw_printenv > /dev/null 2>&1; then
    FW_GET="fw_printenv -n"
elif command -v fw_getenv > /dev/null 2>&1; then
    FW_GET="fw_getenv"
fi

if [ -n "$FW_GET" ]; then
    BOOTPART=$($FW_GET bootpart 2>/dev/null || echo "not set")
    UPGRADE=$($FW_GET upgrade_available 2>/dev/null || echo "not set")
    
    check_info "bootpart: $BOOTPART"
    check_info "upgrade_available: $UPGRADE"
else
    check_warn "U-Boot environment read tool not available, cannot read variables"
fi

echo ""

# Check SWUpdate
check_info "SWUpdate checks:"
if command -v swupdate > /dev/null 2>&1; then
    check_pass "swupdate installed"
    SWUPDATE_VER=$(swupdate -v 2>&1 | head -1)
    check_info "Version: $SWUPDATE_VER"
else
    check_fail "swupdate not installed"
fi

if [ -f "/etc/swupdate/public.pem" ]; then
    check_pass "SWUpdate public key found at /etc/swupdate/public.pem"
else
    check_fail "SWUpdate public key missing"
fi

if [ -f "/etc/swupdate.cfg" ]; then
    check_pass "SWUpdate configuration found"
else
    check_warn "SWUpdate configuration not found"
fi
fi

echo ""

# Summary
echo "=== Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -eq 0 ]; then
    check_pass "All checks passed!"
    exit 0
else
    check_fail "$FAILED check(s) failed"
    exit 1
fi
