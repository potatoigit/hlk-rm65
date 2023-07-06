#
# hua.shao@mediatek.com
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=hostapd
PKG_RELEASE:=$(AUTORELEASE)
PKG_SOURCE_URL:=http://w1.fi/hostap.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_DATE:=2022-01-16
PKG_SOURCE_VERSION:=cff80b4f7d3c0a47c052e8187d671710f48939e4
PKG_MIRROR_HASH:=712965bfa11a2e601d3e1c9a51a2cf3cffc6db89abafb3df3eb0cfd83c64705b
PKG_MAINTAINER:=Felix Fietkau <nbd@nbd.name>
PKG_LICENSE:=BSD-3-Clause
PKG_CPE_ID:=cpe:/a:w1.fi:hostapd
PKG_BUILD_PARALLEL:=1
PKG_ASLR_PIE_REGULAR:=1
PKG_CONFIG_DEPENDS:= \
	CONFIG_PACKAGE_hostapd


include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk

define Package/hostapd
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=WirelessAPD
  TITLE:=IEEE 802.1x Authenticator
  URL:=http://hostap.epitest.fi/
  USERID:=network=101:network=101
  PROVIDES:=hostapd
  CONFLICTS:=$(HOSTAPD_PROVIDERS)
  HOSTAPD_PROVIDERS+=$(1)
  DEPENDS:= +libnl-tiny +libopenssl
endef

define Package/hostapd/description
  WPA hostapd MTK
endef

CONFIGURE_VARS += \
	LIBDBI_CFLAGS="-I$(STAGING_DIR)/usr/include"

ifneq ($(wildcard $(PKG_BUILD_DIR)/.config_*),$(subst .configured_,.config_,$(STAMP_CONFIGURED)))
  define Build/Configure/rebuild
	$(FIND) $(PKG_BUILD_DIR) -name \*.o -or -name \*.a | $(XARGS) rm -f
	rm -f $(PKG_BUILD_DIR)/hostapd/hostapd
	rm -f $(PKG_BUILD_DIR)/hostapd/t.config_*
	touch $(subst .configured_,.config_,$(STAMP_CONFIGURED))
  endef
endif

DRIVER_MAKEOPTS= \
    CONFIG_DRIVER_NL80211=y

TARGET_CPPFLAGS += \
    -I$(PKG_BUILD_DIR)/src \
    -I$(PKG_BUILD_DIR)/src/utils \
    -I/include \
    -I$(STAGING_DIR)/usr/include/openssl \
    -I$(STAGING_DIR)/usr/include \
	-D_GNU_SOURCE \
	-I$(LINUX_DIR)/user_headers/include \
	-I$(STAGING_DIR)/usr/include/libnl-tiny \
	-I$(PKG_BUILD_DIR) \
	-I$(BUILD_DIR)/openssl-1.0.2n/include \
    -DCONFIG_LIBNL20 \
    -D_GNU_SOURCE \
    -DCONFIG_MSG_MIN_PRIORITY=0

TARGET_CFLAGS += \
	-ffunction-sections \
	-fdata-sections \
	-DNO_TIMESTAMP_CHECK

TARGET_LDFLAGS += -Wl,--gc-sections -lnl-tiny -lssl -lcrypto
TARGET_CONFIGURE_OPTS += CONFIG_P2P=y CONFIG_INTERNAL_LIBTOMMATH=y


CFLAGS="$(TARGET_CFLAGS)"

define Build/Configure
	$(Build/Configure/rebuild)
	$(CP) ./files/hostapd-mini.config $(PKG_BUILD_DIR)/hostapd/.config
endef

define Build/RunMake
	CFLAGS="$(TARGET_CPPFLAGS) $(TARGET_CFLAGS)" \
	$(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR)/$(1) \
		$(TARGET_CONFIGURE_OPTS) \
		$(DRIVER_MAKEOPTS) \
		LIBS="$(TARGET_LDFLAGS)" \
		LIBS_c="$(TARGET_LDFLAGS_C)" \
		BCHECK= \
		$(2)
endef

define Build/Compile/hostapd
	+$(call Build/RunMake,hostapd, \
		hostapd hostapd_cli \
	)
endef

define Build/Compile
	$(Build/Compile/hostapd)
endef

define Package/hostapd/install
	$(INSTALL_DIR) $(1)/usr/bin
#	$(CP) $(PKG_BUILD_DIR)/hostapd/hostapd $(PKG_BUILD_DIR)/hostapd/hostapd-2.10
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hostapd/hostapd $(1)/usr/bin
	$(CP) $(PKG_BUILD_DIR)/hostapd/hostapd  $(1)/usr/bin/
	$(CP) $(PKG_BUILD_DIR)/hostapd/hostapd_cli $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc
	$(CP) files/hostapd.conf $(1)/etc/
	$(CP) files/hostapd_ra0_open.conf $(1)/etc/
	$(CP) files/hostapd_rai0_open.conf $(1)/etc/
	$(CP) files/hostapd_ra0_wpa2psk.conf $(1)/etc/
	$(CP) files/hostapd_rai0_wpa2psk.conf $(1)/etc/
#	$(CP) files/hostapd_ra0_map.conf $(1)/etc/
#	$(CP) files/hostapd_ra1_map.conf $(1)/etc/
#	$(CP) files/hostapd_ra2_map.conf $(1)/etc/
#	$(CP) files/hostapd_ra3_map.conf $(1)/etc/
#	$(CP) files/hostapd_rax0_map.conf $(1)/etc/
#	$(CP) files/hostapd_rax1_map.conf $(1)/etc/
#	$(CP) files/hostapd_rax2_map.conf $(1)/etc/
#	$(CP) files/hostapd_rax3_map.conf $(1)/etc/
#	$(CP) files/hostapd-wpa3  $(1)/usr/bin/
#	$(CP) files/hostapd-wpa3_cli $(1)/usr/bin/
	$(CP) files/hostapd_ra0_sae.conf $(1)/etc/
	$(CP) files/hostapd_rai0_sae.conf $(1)/etc/
	$(CP) files/hostapd_ra0_owe.conf $(1)/etc/
	$(CP) files/hostapd_rai0_owe.conf $(1)/etc/
#	$(CP) files/hostapd_ra0_wpa3.conf $(1)/etc/
#	$(CP) files/hostapd_rai0_wpa3.conf $(1)/etc/
#	$(CP) files/hostapd_ra0_owe_sigma.conf $(1)/etc/
#	$(CP) files/hostapd_rai0_owe_sigma.conf $(1)/etc/
#	$(CP) files/hostapd_ra0_wpa3_sigma.conf $(1)/etc/
#	$(CP) files/hostapd_rax0_wpa3_sigma.conf $(1)/etc/
#	$(CP) files/hostapd_rax0.conf $(1)/etc/
#	$(CP) files/hostapd_ra0.conf $(1)/etc/
	$(CP) files/hostapd_rax0_sae.conf $(1)/etc/
	$(CP) files/hostapd_rax0_owe.conf $(1)/etc/
	$(CP) files/hostapd_common.conf $(1)/etc/
	$(CP) files/hostapd_generate.sh $(1)/usr/bin
	$(CP) files/hostapd_ap.sh $(1)/usr/bin
	$(CP) files/hostapd_app.sh $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/init.d/
	$(CP) files/hostapd_init $(1)/etc/init.d
#	$(CP) files/hostapd_ap_11r.sh $(1)/usr/bin
#	$(CP) files/hostapd_rai0_AP_11r.conf $(1)/etc/
	$(CP) files/hostapd_stop.sh $(1)/usr/bin
endef

$(eval $(call BuildPackage,hostapd))


