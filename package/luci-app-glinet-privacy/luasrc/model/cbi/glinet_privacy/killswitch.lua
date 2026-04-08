--[[
Kill switch — UCI: privacy
]]

local sys = require "luci.sys"

m = Map("privacy", translate("Privacy kill switch"),
	translate("When enabled, the watchdog drops forwarded traffic from LAN to the physical WAN if WireGuard or Tor is unhealthy. Configure interfaces to match <code>ip link</code> and your WWAN device."))

s = m:section(NamedSection, "main", "privacy", translate("Settings"))
s.addremove = false

s:option(Flag, "enabled", translate("Enable watchdog"),
	translate("If disabled, killswitch rules are flushed.")).rmempty = false

s:option(Value, "wg_if", translate("WireGuard interface"), translate("e.g. wg0")).rmempty = true
s:option(Flag, "require_wg", translate("Require WG interface UP")).rmempty = false
s:option(Flag, "require_tor", translate("Require Tor running")).rmempty = false
s:option(Value, "lan_dev", translate("LAN bridge / device"), translate("e.g. br-lan; leave empty to use network.lan.device")).rmempty = true
s:option(Value, "wan_dev", translate("Physical WAN device"), translate("e.g. wwan0 or eth0; required for correct FORWARD match")).rmempty = true

function m.on_commit(self)
	sys.call("/usr/bin/privacy-killswitch-watchdog.sh >/dev/null 2>&1")
end

return m
