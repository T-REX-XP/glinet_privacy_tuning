--[[
VPN / tunnel interfaces via OpenWrt `ifstatus` / `ubus call network.interface.<name> status`.
Callers must pass **sanitized** interface / section names (see sanitize.lua).
]]

local sys = require "luci.sys"
local san = require "luci.glinet_privacy.sanitize"

local function parse_ifstatus_json(raw)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local jsonc_mod
	pcall(function()
		jsonc_mod = require "luci.jsonc"
	end)
	if type(jsonc_mod) == "table" and jsonc_mod.parse then
		local ok, t = pcall(jsonc_mod.parse, raw)
		if ok and type(t) == "table" then
			return t
		end
	end
	if raw:match('"up"%s*:%s*true') then
		return { up = true }
	end
	if raw:match('"up"%s*:%s*false') then
		return { up = false }
	end
	return nil
end

local function iface_network_status(name)
	local n = san.sanitize_ifname(name)
	if not n then
		return nil
	end
	local raw = sys.exec("ifstatus " .. n .. " 2>/dev/null")
	if type(raw) ~= "string" or raw == "" then
		raw = sys.exec("ubus call network.interface." .. n .. " status 2>/dev/null")
	end
	return parse_ifstatus_json(raw)
end

--- @return boolean|nil  true/false when ubus/ifstatus answered; nil if unavailable
local function iface_up(name)
	local t = iface_network_status(name)
	if not t then
		return nil
	end
	return t.up == true
end

local function first_ipv4(t)
	if type(t) ~= "table" then
		return nil
	end
	local arr = t["ipv4-address"]
	if type(arr) == "table" and arr[1] and type(arr[1].address) == "string" then
		return arr[1].address
	end
	return nil
end

--- English fragment for Overview detail: "up, 10.0.0.2" / "down" / "no ifstatus (name)"
local function iface_fragment(name)
	local n = san.sanitize_ifname(name)
	if not n then
		return ""
	end
	local t = iface_network_status(n)
	if not t then
		return "no ifstatus (" .. n .. ")"
	end
	if t.up == true then
		local ip = first_ipv4(t)
		if ip then
			return "up, " .. ip
		end
		return "up"
	end
	return "down"
end

--- Prefer `iface_up` when known; else nil (caller keeps e.g. `ip link` result).
local function wg_logical_up(wg_iface)
	return iface_up(wg_iface)
end

--- Lines for Overview: primary `privacy.main.wg_if`, then other `network` wireguard / openvpn sections.
local function overview_vpn_detail_lines(uc, wg_if_privacy_sanitized_or_nil)
	local lines = {}
	local wg = wg_if_privacy_sanitized_or_nil
	if wg and wg ~= "" then
		local frag = iface_fragment(wg)
		if frag ~= "" then
			lines[#lines + 1] = "ifstatus " .. wg .. ": " .. frag
		end
	end

	local seen = {}
	if wg then
		seen[wg] = true
	end

	uc:foreach("network", "interface", function(s)
		local name = s[".name"]
		if not san.sanitize_ifname(name) or seen[name] then
			return
		end
		local proto = uc:get("network", name, "proto") or ""
		if proto == "openvpn" then
			seen[name] = true
			local frag = iface_fragment(name)
			if frag ~= "" then
				lines[#lines + 1] = "OpenVPN " .. name .. ": " .. frag
			end
		elseif proto == "wireguard" then
			seen[name] = true
			local frag = iface_fragment(name)
			if frag ~= "" then
				lines[#lines + 1] = "WireGuard " .. name .. ": " .. frag
			end
		end
	end)

	return lines
end

return {
	iface_up = iface_up,
	iface_fragment = iface_fragment,
	wg_logical_up = wg_logical_up,
	overview_vpn_detail_lines = overview_vpn_detail_lines,
}
