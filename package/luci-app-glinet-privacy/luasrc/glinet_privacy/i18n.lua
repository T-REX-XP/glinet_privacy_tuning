--[[ Load gettext catalog for this app (glinet_privacy.<lang>.lmo in /usr/lib/lua/luci/i18n/) ]]
local i18n = require "luci.i18n"
if i18n.loadc then
	i18n.loadc("glinet_privacy")
end
