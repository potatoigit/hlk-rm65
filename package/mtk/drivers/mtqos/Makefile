# All rights reserved.
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=mtqos
PKG_REVISION:=b59e26d1
PKG_SOURCE:=$(PKG_NAME)-$(PKG_REVISION).tar.bz2

include $(INCLUDE_DIR)/package.mk


define KernelPackage/mtqos
  CATEGORY:=MTK Properties
  TITLE:=MTK QoS module
  FILES:=$(PKG_BUILD_DIR)/mtqos.ko
  AUTOLOAD:=$(call AutoProbe,mtqos)
  SUBMENU:=Drivers
  KCONFIG:=CONFIG_MTQOS_SUPPORT=y
endef


EXTRA_KCONFIG:= \
	CONFIG_MTQOS_SUPPORT=m


EXTRA_CFLAGS:= \
	$(patsubst CONFIG_%, -DCONFIG_%=1, $(patsubst %=m,%,$(filter %=m,$(EXTRA_KCONFIG)))) \
	$(patsubst CONFIG_%, -DCONFIG_%=1, $(patsubst %=y,%,$(filter %=y,$(EXTRA_KCONFIG))))

EXTRA_CFLAGS += -Wall -Werror

define Build/Compile
	+$(MAKE) $(PKG_JOBS) -C "$(LINUX_DIR)" \
		ARCH="$(LINUX_KARCH)" \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		M="$(PKG_BUILD_DIR)" \
		EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
		$(EXTRA_KCONFIG) \
		modules
endef

$(eval $(call KernelPackage,mtqos))
