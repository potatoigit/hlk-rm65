#
# Copyright (C) 2006-2012 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libmapd
PKG_REVISION:=237ad716
PKG_SOURCE:=$(PKG_NAME)-$(PKG_REVISION).tar.bz2
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk

define Package/libmapd
  SECTION:=MTK Properties
  CATEGORY:=MTK Properties
  SUBMENU:=Libraries
  TITLE:=mtk mapd library
endef

define Package/libmapd/description
  mtk mapd library
endef

include ./mapd_config

TARGET_CFLAGS += $(FPIC)

ifeq ($(CONFIG_MULTIAP),y)
TARGET_CFLAGS += -DSUPPORT_MULTI_AP
endif

ifeq ($(CONFIG_MTK_MAP_R2_6E_SUPPORT), y)
TARGET_CFLAGS += -DMAP_6E_SUPPORT
endif

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		$(MAKE_FLAGS) \
		$(TARGET_CONFIGURE_OPTS) \
		CFLAGS="$(TARGET_CFLAGS)" \
		shared
endef

define Build/InstallDev
	$(INSTALL_DIR)  $(1)/usr/include
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/include/mapd_interface_ctrl.h  $(1)/usr/include/
	$(INSTALL_DIR)  $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libmapd_interface_client.so* $(1)/usr/lib/
endef

define Package/libmapd/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libmapd_interface_client.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libmapd))
