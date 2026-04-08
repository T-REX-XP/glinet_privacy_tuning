--[[
Tor NAT + telemetry — single Map for glinet_privacy (avoids wiping sibling sections)
]]

local sys = require "luci.sys"

m = Map("glinet_privacy", translate("Tor & telemetry"),
	translate("Tor transparent NAT is applied by the glinet-privacy firewall plugin. Telemetry uses dnsmasq black-holes and optional vendor UCI toggles. Device profile (GL-XE300 Puli vs GL-AXT1800 Slate AX, etc.) is set by /usr/libexec/glinet-privacy/apply-device-profile.sh."))

h = m:section(NamedSection, "hw", "device", translate("Device profile"))
h.addremove = false
h:option(DummyValue, "slug", translate("Detected profile"),
	translate("puli_xe300 = cellular; slate_ax1800 / gl_ax1800 = Ethernet travel routers (no LTE modem)."))
h:option(DummyValue, "board_hint", translate("Board hint"))
h:option(Flag, "auto_wan", translate("Auto WAN device"),
	translate("When on, apply-device-profile sets privacy.main.wan_dev for Puli (wwan0) or clears mistaken wwan0 on Slate/Flint.")).rmempty = false

s = m:section(NamedSection, "tor", "firewall", translate("Transparent Tor"))
s.addremove = false

s:option(Flag, "tor_transparent", translate("Enable Tor NAT redirects"),
	translate("When enabled, fw-plugin runs /etc/firewall.privacy-tor.sh on firewall reload.")).rmempty = false

s:option(Value, "lan_cidr", translate("LAN CIDR"), translate("Exclude local destinations from TCP redirect.")).rmempty = true
s:option(Value, "router_lan_ip", translate("Router LAN IP"), translate("DNS redirect exception.")).rmempty = true
s:option(Value, "lan_dev", translate("LAN device"), translate("Empty = network.lan.device.")).rmempty = true
s:option(Value, "tor_trans_port", translate("Tor TransPort"), translate("Default 9040")).rmempty = true
s:option(Value, "tor_dns_port", translate("Tor DNSPort"), translate("Default 9053")).rmempty = true

t = m:section(NamedSection, "tel", "telemetry", translate("Telemetry"))
t.addremove = false

t:option(Flag, "block_domains", translate("Enable dnsmasq blocklist"),
	translate("Symlinks /etc/glinet-privacy/glinet-block.conf into /etc/dnsmasq.d/.")).rmempty = false

t:option(Flag, "disable_vendor_cloud", translate("Run vendor disable script"),
	translate("Runs /usr/bin/disable-glinet-telemetry.sh on save.")).rmempty = false

function m.on_commit(self)
	sys.call("/etc/init.d/firewall reload >/dev/null 2>&1")
	sys.call("/usr/libexec/glinet-privacy/apply-telemetry.sh >/dev/null 2>&1")
	sys.call("/etc/init.d/dnsmasq restart >/dev/null 2>&1")
end

return m
