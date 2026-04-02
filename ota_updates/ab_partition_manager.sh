#!/bin/sh
# A/B Partition Manager for SWUpdate OTA
# This script manages dual-partition system with U-Boot bootloader
# Supports partition toggling, rollback, and health checking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Partition configuration
PARTITION_A=2
PARTITION_B=3
BOOT_VAR="bootpart"
UPGRADE_VAR="upgrade_available"
ROLLBACK_VAR="bootcount"
ROLLBACK_LIMIT=3

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

log_success() {
    echo -e "${GREEN}✓${NC}  $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

log_error() {
    echo -e "${RED}✗${NC}  $1" >&2
}

# Check if fw_setenv is available
check_fw_tools() {
    if ! command -v fw_setenv > /dev/null 2>&1; then
        log_error "fw_setenv not found. Please ensure u-boot-tools are installed."
        return 1
    fi
    if ! command -v fw_printenv > /dev/null 2>&1 && ! command -v fw_getenv > /dev/null 2>&1; then
        log_error "U-Boot environment read tool (fw_printenv or fw_getenv) not found."
        return 1
    fi
    return 0
}

# Internal helper to read U-Boot variables
_fw_getenv() {
    local var=$1
    if command -v fw_printenv > /dev/null 2>&1; then
        fw_printenv -n "$var" 2>/dev/null
    elif command -v fw_getenv > /dev/null 2>&1; then
        fw_getenv "$var" 2>/dev/null
    else
        return 1
    fi
}

# Check if fw_env.config exists
check_fw_config() {
    if [ ! -f /etc/fw_env.config ]; then
        log_error "/etc/fw_env.config not found"
        return 1
    fi
    return 0
}

# Get current active partition
get_active_partition() {
    check_fw_tools || return 1
    check_fw_config || return 1
    
    local bootpart=$(_fw_getenv "$BOOT_VAR" || echo "$PARTITION_A")
    # Ensure bootpart is either 2 or 3
    if [ "$bootpart" != "$PARTITION_A" ] && [ "$bootpart" != "$PARTITION_B" ]; then
        log_warn "Invalid bootpart value: $bootpart, defaulting to $PARTITION_A"
        bootpart=$PARTITION_A
    fi
    echo "$bootpart"
}

# Set next boot partition
set_boot_partition() {
    local target=$1
    if [ -z "$target" ]; then
        log_error "set_boot_partition: No partition specified"
        return 1
    fi
    
    if [ "$target" != "$PARTITION_A" ] && [ "$target" != "$PARTITION_B" ]; then
        log_error "Invalid partition: $target (must be $PARTITION_A or $PARTITION_B)"
        return 1
    fi
    
    check_fw_tools || return 1
    check_fw_config || return 1
    
    fw_setenv "$BOOT_VAR" "$target" 2>/dev/null || {
        log_error "Failed to set $BOOT_VAR to $target"
        return 1
    }
    
    log_success "Boot partition set to: $target"
    return 0
}

# Get inactive partition (opposite of current)
get_inactive_partition() {
    local active=$(get_active_partition) || return 1
    if [ "$active" = "$PARTITION_A" ]; then
        echo "$PARTITION_B"
    else
        echo "$PARTITION_A"
    fi
}

# Verify partition device exists and is writable
verify_partition() {
    local part=$1
    local device="/dev/mmcblk0p$part"
    
    if [ ! -b "$device" ]; then
        log_error "Partition device not found: $device"
        return 1
    fi
    
    if [ ! -w "$device" ]; then
        log_error "Partition not writable: $device (need root)"
        return 1
    fi
    
    return 0
}

# Get target partition for update
get_update_target() {
    get_inactive_partition || return 1
}

# Set upgrade flag
set_upgrade_flag() {
    check_fw_tools || return 1
    check_fw_config || return 1
    
    fw_setenv "$UPGRADE_VAR" "1" 2>/dev/null || {
        log_error "Failed to set upgrade flag"
        return 1
    }
    log_success "Upgrade flag set"
    return 0
}

# Clear upgrade flag (after successful boot)
clear_upgrade_flag() {
    check_fw_tools || return 1
    check_fw_config || return 1
    
    fw_setenv "$UPGRADE_VAR" "0" 2>/dev/null || {
        log_warn "Could not clear upgrade flag"
    }
}

# Get upgrade flag status
get_upgrade_status() {
    check_fw_tools || return 1
    check_fw_config || return 1
    
    _fw_getenv "$UPGRADE_VAR" || echo "0"
}

# Reset bootcount for rollback detection
reset_bootcount() {
    check_fw_tools || return 1
    check_fw_config || return 1
    
    fw_setenv "$ROLLBACK_VAR" "0" 2>/dev/null || {
        log_warn "Could not reset bootcount"
    }
    log_success "Bootcount reset"
}

# Display partition status
show_status() {
    log_info "=== A/B Partition Status ==="
    
    if ! check_fw_tools 2>/dev/null; then
        log_error "U-Boot tools not available"
        return 1
    fi
    
    if ! check_fw_config 2>/dev/null; then
        log_error "fw_env.config not found"
        return 1
    fi
    
    local active=$(get_active_partition 2>/dev/null) || return 1
    local inactive=$(get_inactive_partition 2>/dev/null) || return 1
    
    echo -e "Active Partition:   ${GREEN}$active${NC}"
    echo -e "Inactive Partition: ${YELLOW}$inactive${NC}"
    echo -e "Upgrade Flag:       $(get_upgrade_status)"
    
    # Show partition sizes
    for part in $PARTITION_A $PARTITION_B; do
        local device="/dev/mmcblk0p$part"
        if [ -b "$device" ]; then
            local size=$(blockdev --getsz "$device" 2>/dev/null || echo "unknown")
            echo "Partition $part: $size sectors"
        fi
    done
    
    return 0
}

# Perform rollback to previous partition
perform_rollback() {
    log_warn "Initiating rollback..."
    
    check_fw_tools || return 1
    check_fw_config || return 1
    
    local current=$(get_active_partition) || return 1
    local previous=$PARTITION_A
    
    if [ "$current" = "$PARTITION_A" ]; then
        previous=$PARTITION_B
    fi
    
    log_info "Rolling back to partition $previous..."
    set_boot_partition "$previous" || return 1
    
    clear_upgrade_flag || true
    reset_bootcount || true
    
    log_success "Rollback configured. Please reboot."
    return 0
}

# Display help
show_help() {
    cat << "EOF"
A/B Partition Manager for SWUpdate

Usage: ab_partition_manager.sh [COMMAND] [OPTIONS]

Commands:
  status                  Show current A/B partition status
  get-active             Get currently active partition
  get-inactive           Get inactive partition (update target)
  get-update-target      Get partition to write OTA update to
  set-boot <partition>   Set boot partition (2 or 3)
  verify-partition <num>  Verify partition is accessible
  set-upgrade-flag       Mark system as having pending upgrade
  clear-upgrade-flag     Clear upgrade flag (safe boot confirmation)
  reset-bootcount        Reset rollback bootcount counter
  rollback               Perform rollback to previous partition
  check-tools            Verify fw_setenv/fw_getenv availability
  help                   Show this help message

Examples:
  # Show status
  ./ab_partition_manager.sh status

  # Get target for update
  TARGET=$(./ab_partition_manager.sh get-update-target)
  echo "Write update to partition: $TARGET"

  # Rollback after failed boot
  ./ab_partition_manager.sh rollback

EOF
}

# Main command dispatcher
main() {
    local cmd=${1:-status}
    
    case "$cmd" in
        status)
            show_status
            ;;
        get-active)
            get_active_partition
            ;;
        get-inactive)
            get_inactive_partition
            ;;
        get-update-target)
            get_update_target
            ;;
        set-boot)
            set_boot_partition "$2"
            ;;
        verify-partition)
            verify_partition "$2"
            ;;
        set-upgrade-flag)
            set_upgrade_flag
            ;;
        clear-upgrade-flag)
            clear_upgrade_flag
            ;;
        reset-bootcount)
            reset_bootcount
            ;;
        rollback)
            perform_rollback
            ;;
        check-tools)
            check_fw_tools && log_success "U-Boot tools available"
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            log_error "Unknown command: $cmd"
            show_help
            return 1
            ;;
    esac
}

# Run if not sourced
main "$@"
