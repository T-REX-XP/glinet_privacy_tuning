# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# LuCI application (JavaScript views + menu.d). Sits next to ../version.mk.

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/package.mk

PKG_NAME:=luci-app-glinet-privacy
PKG_VERSION:=$(shell sed -n 's/^GLINET_PRIVACY_VERSION:=//p' $(CURDIR)/../version.mk)
PKG_RELEASE:=$(shell sed -n 's/^GLINET_PRIVACY_RELEASE:=//p' $(CURDIR)/../version.mk)

PKG_MAINTAINER:=GL.iNet Privacy contributors
PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=../../LICENSE

PKG_BUILD_DEPENDS:=luci-base/host

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

LUCI_I18N_DOMAIN:=glinet_privacy

define Package/luci-app-glinet-privacy
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI GL.iNet Privacy UI (JavaScript)
  DEPENDS:=+luci-base +glinet-privacy
  URL:=https://github.com/T-REX-XP/glinet_privacy_tuning
  PKGARCH:=all
endef

define Package/luci-app-glinet-privacy/description
 LuCI JS UI: overview, kill switch, IMEI, Tor/DNS/telemetry, verify (requires glinet-privacy).
 No Lua runtime required.
endef

define Package/luci-app-glinet-privacy/conffiles
/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json
/usr/share/luci/menu.d/luci-app-glinet-privacy.json
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/i18n
	@if [ ! -x "$(STAGING_DIR_HOSTPKG)/bin/po2lmo" ]; then \
		echo "luci-app-glinet-privacy: po2lmo missing (need luci-base/host)" >&2; \
		exit 1; \
	fi
	set -e; \
	for po in $$(sort $(wildcard $(CURDIR)/po/*/$(LUCI_I18N_DOMAIN).po)); do \
		[ -f "$$po" ] || continue; \
		lang=$$(basename "$$(dirname "$$po")"); \
		"$(STAGING_DIR_HOSTPKG)/bin/po2lmo" "$$po" "$(PKG_BUILD_DIR)/i18n/$(LUCI_I18N_DOMAIN).$$lang.lmo"; \
	done
endef

define Package/luci-app-glinet-privacy/install
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/glinet_privacy
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/glinet_privacy/*.js \
		$(1)/www/luci-static/resources/view/glinet_privacy/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(foreach lmo,$(wildcard $(PKG_BUILD_DIR)/i18n/$(LUCI_I18N_DOMAIN).*.lmo), \
		$(INSTALL_DATA) $(lmo) $(1)/usr/lib/lua/luci/i18n/;)
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
