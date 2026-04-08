#
# Copyright (C) 2026
# SPDX-License-Identifier: MIT
#

THISDIR:=$(dir $(lastword $(MAKEFILE_LIST)))
include $(TOPDIR)/rules.mk

include $(THISDIR)../version.mk
PKG_NAME:=glinet-privacy
PKG_VERSION:=$(GLINET_PRIVACY_VERSION)
PKG_RELEASE:=$(GLINET_PRIVACY_RELEASE)

PKG_MAINTAINER:=
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/glinet-privacy
  SECTION:=net
  CATEGORY:=Network
  TITLE:=GL.iNet Privacy core (firewall plugin, scripts, UCI)
  DEPENDS:=+iptables +iptables-mod-nat +iptables-mod-extra +iptables-mod-comment
  PKGARCH:=all
endef

define Package/glinet-privacy/description
  Firewall include plugin for Tor NAT redirects, dnsmasq DNS policy (Tor), kill switch watchdog,
  IMEI rotation helpers, and telemetry helpers. Integrates with OpenWrt firewall4/fw3.
endef

define Build/Compile
endef

define Package/glinet-privacy/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/* $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/usr/libexec/glinet-privacy
	$(INSTALL_BIN) ./files/usr/libexec/glinet-privacy/* $(1)/usr/libexec/glinet-privacy/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/* $(1)/etc/init.d/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/etc/config/* $(1)/etc/config/
	$(INSTALL_BIN) ./files/etc/firewall.privacy-tor.sh $(1)/etc/firewall.privacy-tor.sh
	$(INSTALL_DIR) $(1)/etc/tor/torrc.d
	$(INSTALL_DATA) ./files/etc/tor/torrc.d/* $(1)/etc/tor/torrc.d/
	$(INSTALL_DIR) $(1)/etc/crontabs
	$(INSTALL_DATA) ./files/etc/crontabs/* $(1)/etc/crontabs/
	$(INSTALL_DIR) $(1)/etc/glinet-privacy
	$(INSTALL_DATA) ./files/etc/glinet-privacy/* $(1)/etc/glinet-privacy/
	$(INSTALL_DIR) $(1)/usr/share/glinet-privacy
	$(INSTALL_DATA) ./../version.mk $(1)/usr/share/glinet-privacy/version.mk
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/* $(1)/etc/uci-defaults/
endef

define Package/glinet-privacy/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
[ -x /usr/bin/apply-privacy-firewall-includes.sh ] && /usr/bin/apply-privacy-firewall-includes.sh
/etc/init.d/firewall reload 2>/dev/null || true
exit 0
endef

$(eval $(call BuildPackage,glinet-privacy))
