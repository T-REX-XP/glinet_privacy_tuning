--[[
Kill switch — UCI: privacy
]]

local i18n = require "luci.glinet_privacy.i18n"
local translate = i18n.translate
local sys = require "luci.sys"

m = Map("privacy", translate("Privacy kill switch"),
	translate("Configure the glinet-privacy watchdog (iptables). <strong>VPN:</strong> set up WireGuard or OpenVPN in the GL.iNet admin first, then set <strong>WireGuard interface</strong> to the name of the tunnel when it is up (<em>Network → Interfaces</em> or <code>ip link</code>; often <code>wgclient</code> or <code>wg0</code>). Turn off <strong>Require WG interface UP</strong> if you use only OpenVPN or no VPN. <strong>Overview</strong> shows interface status. Stock firmware may offer a separate VPN kill switch — see below."))

s = m:section(NamedSection, "main", "privacy", translate("Privacy watchdog (glinet-privacy)"))
s.addremove = false

s:option(Flag, "enabled", translate("Enable watchdog"),
	translate("If disabled, killswitch rules are flushed.")).rmempty = false

s:option(Value, "wg_if", translate("WireGuard interface"),
	translate("Must match the interface name when your stock VPN client has brought WireGuard up (e.g. wgclient, wg0). Preconfigure the VPN in the GL.iNet UI first.")).rmempty = true
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
