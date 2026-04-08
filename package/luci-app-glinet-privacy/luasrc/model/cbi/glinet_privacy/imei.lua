--[[
IMEI rotation — UCI: rotate_imei
]]

local i18n = require "luci.glinet_privacy.i18n"
local translate = i18n.translate
local sys = require "luci.sys"

m = Map("rotate_imei", translate("IMEI rotation"),
	translate("Boot-time or cron rotation for Quectel modems via AT+EGMR. Altering IMEI may be unlawful outside operator-authorized or lab use; you are responsible for compliance. See docs/devices.md (IMEI section) in the project repository. Firmware may reject writes. Optional: set ROTATE_IMEI_SUPPRESS_LEGAL_LOG=1 on cron after you have verified compliance."))

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
