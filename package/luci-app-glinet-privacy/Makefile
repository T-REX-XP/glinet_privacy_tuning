# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# LuCI application. Sits next to ../version.mk and depends on glinet-privacy (see ../OPENWRT-BUILD.txt).

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/package.mk

PKG_NAME:=luci-app-glinet-privacy
PKG_VERSION:=$(shell sed -n 's/^GLINET_PRIVACY_VERSION:=//p' $(CURDIR)/../version.mk)
PKG_RELEASE:=$(shell sed -n 's/^GLINET_PRIVACY_RELEASE:=//p' $(CURDIR)/../version.mk)

PKG_MAINTAINER:=GL.iNet Privacy contributors
PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=../../LICENSE

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

define Package/luci-app-glinet-privacy
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI GL.iNet Privacy UI
  DEPENDS:=+luci-base +glinet-privacy
  URL:=https://github.com/T-REX-XP/glinet_privacy_tuning
  PKGARCH:=all
endef

define Package/luci-app-glinet-privacy/description
 LuCI UI: overview, kill switch, IMEI rotation, Tor/DNS/telemetry, verify (requires glinet-privacy).
endef

define Package/luci-app-glinet-privacy/conffiles
/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json
/usr/share/luci/menu.d/luci-app-glinet-privacy.json
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/luci-app-glinet-privacy/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/*.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/glinet_privacy
	$(INSTALL_DATA) ./luasrc/glinet_privacy/*.lua $(1)/usr/lib/lua/luci/glinet_privacy/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/glinet_privacy
	$(INSTALL_DATA) ./luasrc/view/glinet_privacy/*.htm $(1)/usr/lib/lua/luci/view/glinet_privacy/
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json $(1)/usr/share/rpcd/acl.d/
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-glinet-privacy.json $(1)/usr/share/luci/menu.d/
endef

define Package/luci-app-glinet-privacy/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || rm -f /tmp/luci-indexcache* /tmp/luci-modulecache/* 2>/dev/null || true
exit 0
endef

$(eval $(call BuildPackage,luci-app-glinet-privacy))
