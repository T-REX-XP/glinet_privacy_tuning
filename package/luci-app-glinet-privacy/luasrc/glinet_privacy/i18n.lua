--[[
SPDX-License-Identifier: GPL-2.0-only
Copyright (c) 2026 GL.iNet Privacy contributors
Load gettext catalog for this app (glinet_privacy.<lang>.lmo in /usr/lib/lua/luci/i18n/).
Returns luci.i18n so callers can use: local translate = require(...).translate
]]
local i18n = require "luci.i18n"
if i18n.loadc then
	i18n.loadc("glinet_privacy")
end
return i18n
