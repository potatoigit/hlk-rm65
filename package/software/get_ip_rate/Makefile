#
# Copyright (C) 2007-2014 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=get_ip_rate
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/get_ip_rate
	CATEGORY:=SOFTWARE
	#SUBMENU:=get_ip_rate
	SECTION:=soft
	TITLE:=get dhcp ip rate
	DEPENDS:= +libpcap +libpthread
endef

define Package/get_ip_rate/description
	Uses iptables to obtain the ip address allocation rate of the device
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	#$(CP) ./files/* $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)
endef

define Build/Compile
$(MAKE) -C $(PKG_BUILD_DIR) $(TARGET_CONFIGURE_OPTS)
endef

target=$(firstword $(subst -, ,$(BOARD)))

define Package/get_ip_rate/install
	$(INSTALL_DIR) $(1)/etc/init.d		
	$(INSTALL_BIN) ./files/get_ip_rate.init $(1)/etc/init.d/get_ip_rate
	$(INSTALL_DIR) $(1)/etc/config		
	$(INSTALL_BIN) ./files/get_ip_rate.config $(1)/etc/config/get_ip_rate
	#$(INSTALL_DIR) $(1)/sbin
	#$(INSTALL_BIN) ./files/set_iptables_rule $(1)/sbin/set_iptables_rule
	#$(INSTALL_DIR) $(1)/sbin
	#$(INSTALL_BIN) ./files/get_ip_rate $(1)/sbin/get_ip_rate

	$(INSTALL_DIR) $(1)/sbin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/get_ip_rate $(1)/sbin/
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/get_ip_rate $(TARGET_DIR)/sbin/
endef

$(eval $(call BuildPackage,get_ip_rate))
