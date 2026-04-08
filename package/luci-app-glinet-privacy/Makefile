#
# SPDX-License-Identifier: MIT
#

THISDIR:=$(dir $(lastword $(MAKEFILE_LIST)))
include $(TOPDIR)/rules.mk

include $(THISDIR)../version.mk
PKG_NAME:=luci-app-glinet-privacy
PKG_VERSION:=$(GLINET_PRIVACY_VERSION)
PKG_RELEASE:=$(GLINET_PRIVACY_RELEASE)

PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-glinet-privacy
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI for GL.iNet Privacy (kill switch, IMEI, Tor, telemetry)
  DEPENDS:=+luci-base +glinet-privacy
  PKGARCH:=all
endef

define Package/luci-app-glinet-privacy/description
  Web UI for glinet-privacy: kill switch, IMEI rotation, Tor transparent NAT,
  telemetry blocking, and Mullvad helper reference.
endef

define Build/Compile
endef

define Package/luci-app-glinet-privacy/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/glinet_privacy.lua $(1)/usr/lib/lua/luci/controller/glinet_privacy.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/glinet_privacy
	$(INSTALL_DATA) ./luasrc/model/cbi/glinet_privacy/*.lua $(1)/usr/lib/lua/luci/model/cbi/glinet_privacy/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/glinet_privacy
	$(INSTALL_DATA) ./luasrc/view/glinet_privacy/*.htm $(1)/usr/lib/lua/luci/view/glinet_privacy/
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json $(1)/usr/share/rpcd/acl.d/
endef

$(eval $(call BuildPackage,luci-app-glinet-privacy))
