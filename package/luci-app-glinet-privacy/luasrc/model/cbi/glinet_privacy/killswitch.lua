--[[
Kill switch — UCI: privacy
]]

require "luci.glinet_privacy.i18n"

local sys = require "luci.sys"

m = Map("privacy", translate("Privacy kill switch"),
	translate("This page configures the glinet-privacy watchdog (iptables). GL.iNet stock firmware may also offer a VPN kill switch under VPN Dashboard — see below."))

s = m:section(NamedSection, "main", "privacy", translate("Privacy watchdog (glinet-privacy)"))
s.addremove = false

s:option(Flag, "enabled", translate("Enable watchdog"),
	translate("If disabled, killswitch rules are flushed.")).rmempty = false

s:option(Value, "wg_if", translate("WireGuard interface"), translate("e.g. wg0")).rmempty = true
s:option(Flag, "require_wg", translate("Require WG interface UP")).rmempty = false
s:option(Flag, "require_tor", translate("Require Tor running")).rmempty = false
s:option(Value, "lan_dev", translate("LAN bridge / device"), translate("e.g. br-lan; leave empty to use network.lan.device")).rmempty = true
s:option(Value, "wan_dev", translate("Physical WAN device"), translate("e.g. wwan0 or eth0; required for correct FORWARD match")).rmempty = true

vk = s:option(ListValue, "vendor_gl_vpn_killswitch", translate("GL.iNet vendor VPN kill switch (glvpn)"),
	translate("Stock firmware <em>Block Non-VPN Traffic</em> is often <code>glvpn.general.block_non_vpn</code>. Default <strong>Leave</strong> does not touch vendor UCI. Use On/Off only if that file exists. Prefer one strategy: this watchdog <em>or</em> vendor rules — both may overlap. v4.8+ may use VPN Dashboard instead; see docs/devices.md."))
vk:value("leave", translate("Leave (do not change glvpn)"))
vk:value("on", translate("On (block_non_vpn=1)"))
vk:value("off", translate("Off (block_non_vpn=0)"))
vk.default = "leave"
vk.rmempty = false

function m.on_commit(self)
	sys.call("/usr/libexec/glinet-privacy/apply-vendor-vpn-killswitch.sh >/dev/null 2>&1")
	sys.call("/usr/bin/privacy-killswitch-watchdog.sh >/dev/null 2>&1")
end

return m
