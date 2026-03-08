#!/bin/bash
# A/B OTA Update Package Creator
# Creates signed SWUpdate packages for dual-partition A/B update strategy
# Usage: ./create_ab_update.sh <version> <rootfs_image>

set -e

# Configuration  
PRIV_KEY="${HOME}/swupdate_key/private.pem"
PUB_KEY="./public.pem"
ROOTFS_IMAGE="${2}"
VERSION="${1}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_error() {
    echo -e "${RED}✗${NC}  $1" >&2
}

log_success() {
    echo -e "${GREEN}✓${NC}  $1"
}

log_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

# Validation
if [ -z "$VERSION" ] || [ -z "$ROOTFS_IMAGE" ]; then
    log_error "Usage: ./create_ab_update.sh <version> <rootfs_image>"
    echo "  Example: ./create_ab_update.sh 1.0.1 ../buildroot/output/images/rootfs.ext4"
    exit 1
fi

log_info "=== A/B OTA Package Creator ==="
log_info "Version: $VERSION"
log_info "Rootfs: $ROOTFS_IMAGE"

# Pre-flight checks
log_info "Checking prerequisites..."
for f in "$PRIV_KEY" "$PUB_KEY" "$ROOTFS_IMAGE" "pre_ab_update.sh" "post_ab_update.sh" "ab_partition_manager.sh"; do
    if [ ! -f "$f" ]; then
        log_error "Required file not found: $f"
        exit 1
    fi
done
log_success "All prerequisites found"

# Setup staging directory
STAGING_DIR="swu_staging_ab_${VERSION}"
OUTPUT_FILE="update-ab-${VERSION}.swu"

log_info "Creating staging directory: $STAGING_DIR"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Calculate SHA256 hash
log_info "Calculating rootfs hash..."
ROOTFS_SHA256=$(sha256sum "$ROOTFS_IMAGE" | cut -d " " -f 1)
log_success "Rootfs SHA256: $ROOTFS_SHA256"

# Calculate script hashes
log_info "Calculating script hashes..."
PRE_UPDATE_SHA256=$(sha256sum "pre_ab_update.sh" | cut -d " " -f 1)
POST_UPDATE_SHA256=$(sha256sum "post_ab_update.sh" | cut -d " " -f 1)

# Create sw-description from scratch to ensure no bootenv section exists
log_info "Creating sw-description for A/B update..."
cat > "$STAGING_DIR/sw-description" << EOF
software = {
    version = "$VERSION";
    hardware-compatibility = [ "rpi4" ];

    images: (
        {
            filename = "rootfs.ext4";
            device = "/dev/mmcblk0p3";
            type = "raw";
            installed-directly = true;
            sha256 = "$ROOTFS_SHA256";
        }
    );

    scripts: (
        {
            filename = "pre_ab_update.sh";
            type = "shellscript";
            sha256 = "$PRE_UPDATE_SHA256";
        },
        {
            filename = "post_ab_update.sh";
            type = "shellscript";
            sha256 = "$POST_UPDATE_SHA256";
        }
    );
}
EOF

log_success "sw-description created"

# Verify sw-description is valid
if grep -q "@ROOTFS_SHA256@" "$STAGING_DIR/sw-description"; then
    log_error "sw-description placeholder substitution failed (placeholder still present)"
    exit 1
fi

# Sign the description using RSA-PSS
log_info "Signing sw-description with RSA-PSS..."
openssl dgst -sha256 -sign "$PRIV_KEY" \
    -sigopt rsa_padding_mode:pss \
    -sigopt rsa_pss_saltlen:32 \
    -out "$STAGING_DIR/sw-description.sig" "$STAGING_DIR/sw-description" 2>/dev/null || {
    log_error "Signature generation failed"
    exit 1
}

# Verify signature locally
log_info "Verifying signature..."
if openssl dgst -sha256 -verify "$PUB_KEY" \
    -sigopt rsa_padding_mode:pss \
    -sigopt rsa_pss_saltlen:32 \
    -signature "$STAGING_DIR/sw-description.sig" \
    "$STAGING_DIR/sw-description" 2>/dev/null; then
    log_success "Signature verification: SUCCESS"
else
    log_error "Signature verification failed"
    exit 1
fi

# Copy assets to staging
log_info "Copying update assets..."
cp "$ROOTFS_IMAGE" "$STAGING_DIR/rootfs.ext4"
cp "pre_ab_update.sh" "$STAGING_DIR/"
cp "post_ab_update.sh" "$STAGING_DIR/"  
cp "ab_partition_manager.sh" "$STAGING_DIR/"
log_success "Assets copied"

# Create the SWU archive
log_info "Creating SWU archive with CPIO..."
cd "$STAGING_DIR"

# Order is CRITICAL: sw-description MUST be first
# This is required by SWUpdate to parse the manifest
FILES="sw-description sw-description.sig pre_ab_update.sh post_ab_update.sh ab_partition_manager.sh rootfs.ext4"

for i in $FILES; do
    echo "$i"
done | cpio -ov -H newc > "../$OUTPUT_FILE" || {
    log_error "Failed to create CPIO archive"
    cd ..
    exit 1
}

cd ..

# Verify archive structure
log_info "Verifying archive structure..."
FIRST_FILE=$(cpio -it < "$OUTPUT_FILE" 2>/dev/null | head -n 1)

if [ "$FIRST_FILE" = "sw-description" ]; then
    log_success "Archive structure verified (sw-description is first)"
else
    log_error "Archive structure invalid. First file: $FIRST_FILE (expected: sw-description)"
    exit 1
fi

# Print file list in archive
log_info "Contents of update package:"
cpio -it < "$OUTPUT_FILE" 2>/dev/null | sed 's/^/  /'

# Calculate package checksum
PACKAGE_SHA256=$(sha256sum "$OUTPUT_FILE" | cut -d " " -f 1)
log_success "Package SHA256: $PACKAGE_SHA256"

# Show final summary
echo ""
log_success "=== A/B OTA Package Created Successfully ==="
echo "Package: $OUTPUT_FILE"
echo "Version: $VERSION"
echo "Size: $(du -h "$OUTPUT_FILE" | cut -f1)"
echo "SHA256: $PACKAGE_SHA256"
echo ""
log_info "Next steps:"
echo "  1. Transfer to device: scp -O $OUTPUT_FILE root@<device-ip>:/tmp/"
echo "  2. Verify on device: swupdate -c -i /tmp/$OUTPUT_FILE"
echo "  3. Apply update: swupdate -i /tmp/$OUTPUT_FILE"
echo "  4. Reboot: reboot"
echo ""
log_info "Staging directory: $STAGING_DIR (kept for inspection)"
log_info "To clean up: rm -rf $STAGING_DIR"

exit 0
