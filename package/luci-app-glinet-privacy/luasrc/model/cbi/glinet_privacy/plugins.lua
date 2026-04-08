--[[
Tor NAT + telemetry — single Map for glinet_privacy (avoids wiping sibling sections)
]]

local sys = require "luci.sys"

m = Map("glinet_privacy", translate("Tor, DNS & telemetry"),
	translate("Tor transparent NAT runs via the firewall plugin. DNS policy can forward dnsmasq to Tor or Mullvad. Telemetry uses dnsmasq black-holes and optional vendor toggles. Device profile is set by /usr/libexec/glinet-privacy/apply-device-profile.sh."))

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

t:option(Flag, "disable_vendor_cloud", translate("Disable GL.iNet cloud (UCI + services)"),
	translate("Sets glconfig.cloud.enable=0 where present, stops gl_cloud / goodcloud init scripts, and installs DNS black-holes via /etc/dnsmasq.d/glinet-block.conf (same as reference: goodcloud.xyz, gldns.com).")).rmempty = false

t:option(Flag, "remove_cloud_packages", translate("Remove cloud packages (opkg)"),
	translate("When saving telemetry settings, best-effort uninstall of gl-cloud and related packages (optional; may affect stock GL.iNet features).")).rmempty = false

d = m:section(NamedSection, "dns", "dns", translate("DNS leak reduction"))
d.addremove = false

dp = d:option(ListValue, "dns_policy", translate("Router DNS (dnsmasq)"))
dp:value("default", translate("No automatic change (manual / Mullvad apply script)"))
dp:value("tor_dnsmasq", translate("Forward to Tor (127.0.0.1 → DNSPort)"))
dp:value("mullvad_dnsmasq", translate("Forward to Mullvad DNS IP"))
dp.default = "default"
dp.rmempty = false

d:option(Value, "mullvad_dns", translate("Mullvad DNS address"),
	translate("Used when policy is Mullvad; default matches Mullvad WireGuard DNS (10.64.0.1).")).rmempty = true

d:option(Flag, "redirect_tcp_dns", translate("Redirect LAN TCP/53 to Tor"),
	translate("When transparent Tor is enabled, send LAN TCP DNS to Tor DNSPort (UDP was already redirected).")).rmempty = false

d:option(Flag, "block_lan_dot", translate("Block LAN DNS-over-TLS (port 853)"),
	translate("Drop forwarded TCP/853 from LAN to non-router destinations. Can break DoT to public resolvers; use only if you accept that tradeoff.")).rmempty = false

function m.on_commit(self)
	sys.call("/usr/libexec/glinet-privacy/apply-dns-policy.sh >/dev/null 2>&1")
	sys.call("/etc/init.d/firewall reload >/dev/null 2>&1")
	sys.call("/usr/libexec/glinet-privacy/apply-telemetry.sh >/dev/null 2>&1")
	sys.call("/etc/init.d/dnsmasq restart >/dev/null 2>&1")
end

return m
