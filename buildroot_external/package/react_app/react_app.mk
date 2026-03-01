# Buildroot package definition for react_app

REACT_APP_VERSION = 1.0
REACT_APP_SITE = $(BR2_EXTERNAL_REACTION_TIME_MEASUREMENT_APPLICATION_PATH)/package/react_app
REACT_APP_SITE_METHOD = local
REACT_APP_LICENSE = MIT

REACT_APP_DEPENDENCIES =

# Use the generic build system which simply invokes 'make' in the directory
# containing the source code.
define REACT_APP_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -o $(@D)/react_app $(@D)/react_app.c
endef

define REACT_APP_CLEAN_CMDS
	rm -f $(@D)/react_app
endef

define REACT_APP_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/react_app $(TARGET_DIR)/usr/bin/react_app
endef

$(eval $(generic-package))
