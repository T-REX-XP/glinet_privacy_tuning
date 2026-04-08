--[[
Runtime + UCI network hints for LuCI (aligned with privacy-killswitch-watchdog.sh).
]]

local sys = require "luci.sys"

local bit_ok, bit = pcall(require, "bit")

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

--- LAN network CIDR for Tor exclusion lists (network address with prefix).
local function cidr_from_host_ipcidr(ipcidr)
	if not ipcidr then
		return nil
	end
	local a, b, c, host, p =
		ipcidr:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)/(%d+)$")
	if not a then
		return nil
	end
	p = tonumber(p)
	local ha, hb, hc, hd = tonumber(a), tonumber(b), tonumber(c), tonumber(host)
	if not ha or not p then
		return nil
	end
	if p == 24 then
		return string.format("%s.%s.%s.0/%d", a, b, c, p)
	elseif p == 16 then
		return string.format("%s.%s.0.0/%d", a, b, p)
	elseif p == 8 then
		return string.format("%s.0.0.0/%d", a, p)
	elseif bit_ok and bit and p > 0 and p <= 32 then
		local ipnum = ha * 16777216 + hb * 65536 + hc * 256 + hd
		local mask = bit.rshift(0xffffffff % 0x100000000, 32 - p)
		if p == 32 then
			mask = 0xffffffff
		end
		local net = bit.band(ipnum, mask)
		local o1 = math.floor(net / 16777216) % 256
		local o2 = math.floor(net / 65536) % 256
		local o3 = math.floor(net / 256) % 256
		local o4 = net % 256
		return string.format("%d.%d.%d.%d/%d", o1, o2, o3, o4, p)
	end
	return string.format("%s.%s.%s.0/%d", a, b, c, p)
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

local function glvpn_block_hint(uc)
	if not uc:get("glvpn", "general") then
		return nil
	end
	local v = uc:get("glvpn", "general", "block_non_vpn")
	if v == "1" or v == "true" or v == "yes" then
		return "1"
	end
	if v == "0" or v == "false" or v == "no" then
		return "0"
	end
	return v
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
	local lan_cidr_guess = cidr_from_host_ipcidr(ipcidr)
	local router_ip_uci = uc:get("network", "lan", "ipaddr") or ""

	local router_ip = hostip or router_ip_uci
	local wg = list_wireguard_ifaces()

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
		glvpn_block_non_vpn = glvpn_block_hint(uc),
	}
end

return {
	snapshot = snapshot,
	uci_lan_device = uci_lan_device,
	detect_wan_dev = detect_wan_dev,
	list_wireguard_ifaces = list_wireguard_ifaces,
}
