################################################################################
# aesd_app
################################################################################

AESD_APP_VERSION = local
AESD_APP_SITE = $(TOPDIR)/../../applications/aesd_application
AESD_APP_SITE_METHOD = local

AESD_APP_LICENSE = Proprietary
AESD_APP_LICENSE_FILES = NONE

# Build the application
define AESD_APP_BUILD_CMDS
	$(MAKE) -C $(@D) CC="$(TARGET_CC)" AR="$(TARGET_AR)" LD="$(TARGET_LD)"
endef

# Install binary into target rootfs
define AESD_APP_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/aesd_app $(TARGET_DIR)/usr/bin/aesd_app
endef

$(eval $(generic-package))