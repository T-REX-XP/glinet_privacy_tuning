--[[
Runtime + UCI network hints for LuCI (aligned with privacy-killswitch-watchdog.sh).
]]

local sys = require "luci.sys"

local function trim(s)
	if type(s) ~= "string" then
		return ""
	end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Prefer network.lan.device, then legacy ifname, else br-lan.
local function uci_lan_device(uc)
	local d = uc:get("network", "lan", "device")
	if d and d ~= "" then
		return d
	end
	d = uc:get("network", "lan", "ifname")
	if d and d ~= "" then
		return d
	end
	return "br-lan"
end

--- WAN device: saved privacy.main.wan_dev, else network.{wan,wwan,modem}.device, else default route dev.
local function detect_wan_dev(uc, privacy_wan_saved)
	if privacy_wan_saved and privacy_wan_saved ~= "" then
		return privacy_wan_saved, "privacy.uci"
	end
	for _, n in ipairs({ "wan", "wwan", "modem" }) do
		if uc:get("network", n) then
			local d = uc:get("network", n, "device")
			if d and d ~= "" then
				return d, "network." .. n
			end
		end
	end
	local out = trim(sys.exec("ip -4 route show default 2>/dev/null | head -1") or "")
	local dev = out:match("%sdev%s+(%S+)")
	if dev then
		return dev, "route.default"
	end
	return "", ""
end

--- First IPv4 CIDR on device (host/prefix), e.g. 192.168.8.1/24
local function ip_addr_on_dev(dev)
	if not dev or dev == "" then
		return nil, nil
	end
	local out = sys.exec("ip -o -f inet addr show dev " .. dev .. " 2>/dev/null | head -1") or ""
	local ipcidr = out:match("%s(%d+%.%d+%.%d+%.%d+/%d+)%s")
	if not ipcidr then
		return nil, nil
	end
	local a, b, c, d, p = ipcidr:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)/(%d+)$")
	if not a then
		return nil, nil
	end
	return string.format("%s.%s.%s.%s", a, b, c, d), ipcidr
end

--- Connected LAN subnet from kernel route (prefix-accurate, any mask).
local function lan_subnet_route(dev)
	if not dev or dev == "" then
		return nil
	end
	local out = trim(
		sys.exec("ip -o -f inet route show dev " .. dev .. " scope link 2>/dev/null | head -1") or ""
	)
	local cidr = out:match("^(%d+%.%d+%.%d+%.%d+/%d+)%s")
	return cidr
end

local function list_wireguard_ifaces()
	local out = sys.exec("ip -o link show type wireguard 2>/dev/null") or ""
	local list = {}
	local seen = {}
	for line in out:gmatch("[^\r\n]+") do
		local ifname = line:match("^%d+:%s+([^:@%s]+)")
		if ifname and not seen[ifname] then
			seen[ifname] = true
			table.insert(list, ifname)
		end
	end
	table.sort(list)
	return list
end

local function uci_wan_hint_list(uc)
	local rows = {}
	for _, n in ipairs({ "wan", "wan6", "wwan", "modem", "4g", "tethering" }) do
		if uc:get("network", n) then
			local d = uc:get("network", n, "device")
			if d and d ~= "" then
				table.insert(rows, { dev = d, iface = n })
			end
		end
	end
	return rows
end

local function glvpn_snapshot(uc)
	if not uc:get_all("glvpn") then
		return false, nil
	end
	local sid = uc:get_first("glvpn", "general")
	if not sid then
		return false, nil
	end
	local v = uc:get("glvpn", sid, "block_non_vpn")
	if v == nil or v == "" then
		return true, nil
	end
	if v == "1" or v == "true" or v == "yes" or v == "on" then
		return true, "1"
	end
	if v == "0" or v == "false" or v == "no" or v == "off" then
		return true, "0"
	end
	return true, tostring(v)
end

--- @return table fields for templates / controllers
local function snapshot()
	local uc = require "luci.model.uci".cursor()
	local lan_uci = uci_lan_device(uc)
	local privacy_lan = uc:get("privacy", "main", "lan_dev") or ""
	local privacy_wan = uc:get("privacy", "main", "wan_dev") or ""
	local wan_dev, wan_src = detect_wan_dev(uc, privacy_wan)

	local lan_eff = privacy_lan ~= "" and privacy_lan or lan_uci
	local hostip, ipcidr = ip_addr_on_dev(lan_eff)
	local lan_cidr_guess = lan_subnet_route(lan_eff) or ""
	local router_ip_uci = uc:get("network", "lan", "ipaddr") or ""

	local router_ip = hostip or router_ip_uci
	local wg = list_wireguard_ifaces()
	local glvpn_ok, glvpn_val = glvpn_snapshot(uc)

	return {
		lan_device_uci = lan_uci,
		lan_device_privacy_saved = privacy_lan,
		lan_device_effective = lan_eff,
		wan_device_privacy_saved = privacy_wan,
		wan_device_effective = wan_dev,
		wan_source = wan_src,
		router_lan_ip = router_ip or "",
		lan_ip_cidr = ipcidr or "",
		lan_cidr_guess = lan_cidr_guess or "",
		wireguard_ifaces = wg,
		wan_hints = uci_wan_hint_list(uc),
		glvpn_present = glvpn_ok,
		glvpn_block_non_vpn = glvpn_val,
	}
end

return {
	snapshot = snapshot,
	uci_lan_device = uci_lan_device,
	detect_wan_dev = detect_wan_dev,
	list_wireguard_ifaces = list_wireguard_ifaces,
}
