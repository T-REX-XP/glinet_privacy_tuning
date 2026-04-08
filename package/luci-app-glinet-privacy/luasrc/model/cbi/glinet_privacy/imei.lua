--[[
IMEI rotation — UCI: rotate_imei
]]

local sys = require "luci.sys"

m = Map("rotate_imei", translate("IMEI rotation"),
	translate("Boot-time or cron rotation for Quectel modems via AT+EGMR. May be illegal in your jurisdiction; firmware may reject writes."))

s = m:section(NamedSection, "main", "rotate_imei", translate("Settings"))
s.addremove = false

s:option(Flag, "enabled", translate("Run on boot"),
	translate("Uses /etc/init.d/rotate_imei when enabled.")).rmempty = false

s:option(Value, "imei_tac", translate("Optional 8-digit TAC"), translate("Leave empty for fully random Luhn-valid IMEI")).rmempty = true
s:option(Value, "modem_tty", translate("Modem serial device"), translate("e.g. /dev/ttyUSB2")).rmempty = true
s:option(Value, "wwan_if", translate("WWAN logical interface"), translate("uci network section name, e.g. wwan")).rmempty = true

function m.on_commit(self)
	sys.call("/etc/init.d/rotate_imei enable 2>/dev/null")
end

return m
