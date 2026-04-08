--[[
SPDX-License-Identifier: GPL-2.0-only
Copyright (c) 2026 GL.iNet Privacy contributors
Standard LuCI gettext domain "glinet_privacy" (upstream-style .lmo workflow).

Compiled catalogs (from po/*/glinet_privacy.po via po2lmo in the package Makefile):
  /usr/lib/lua/luci/i18n/glinet_privacy.<lang>.lmo

Call require("luci.glinet_privacy.i18n") once per request (controller + templates) so
luci.i18n.loadc("glinet_privacy") runs before <%: … %> / translate().
]]
local i18n = require "luci.i18n"
if i18n.loadc then
	i18n.loadc("glinet_privacy")
end
return i18n
