# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# OpenWrt core package (no LuCI). Must sit next to ../version.mk (see ../OPENWRT-BUILD.txt
# and ../../feeds.conf.example). PKG_LICENSE_FILES points at the repository-root LICENSE.

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/package.mk

PKG_NAME:=glinet-privacy
PKG_VERSION:=$(shell sed -n 's/^GLINET_PRIVACY_VERSION:=//p' $(CURDIR)/../version.mk)
PKG_RELEASE:=$(shell sed -n 's/^GLINET_PRIVACY_RELEASE:=//p' $(CURDIR)/../version.mk)

PKG_MAINTAINER:=GL.iNet Privacy contributors
PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=../../LICENSE

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

define Package/glinet-privacy
  SECTION:=net
  CATEGORY:=Network
  TITLE:=GL.iNet Privacy core (kill switch, Tor hooks, telemetry, IMEI helpers)
  URL:=https://github.com/T-REX-XP/glinet_privacy_tuning
  DEPENDS:=+iptables +ip +dnsmasq
  PKGARCH:=all
endef

define Package/glinet-privacy/description
 Privacy-oriented scripts and UCI: killswitch watchdog, Tor transparent proxy hooks,
 optional dnsmasq→Tor DNS policy, telemetry blocklist, optional Quectel IMEI rotation.
endef

define Package/glinet-privacy/conffiles
/etc/config/privacy
/etc/config/glinet_privacy
/etc/config/rotate_imei
/etc/tor/torrc.d/99-transparent.conf
/etc/glinet-privacy/glinet-block.conf
/etc/firewall.privacy-tor.sh
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/glinet-privacy/install
	$(INSTALL_DIR) $(1)
	$(CP) ./files/* $(1)/
endef

define Package/glinet-privacy/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || /etc/init.d/privacy-killswitch enable >/dev/null 2>&1 || true
exit 0
endef

$(eval $(call BuildPackage,glinet-privacy))
