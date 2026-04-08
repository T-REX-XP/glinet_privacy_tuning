--[[
SPDX-License-Identifier: GPL-2.0-only
Copyright (c) 2026 GL.iNet Privacy contributors
Status probes for killswitch + Tor NAT. Prefers shared libexec scripts (single
source with nft fallbacks); duplicates that logic in Lua only when scripts are missing.
]]

local sys = require "luci.sys"

local KS_SCRIPT = "/usr/libexec/glinet-privacy/killswitch-drop-active.sh"
local TOR_SCRIPT = "/usr/libexec/glinet-privacy/tor-transparent-nat-active.sh"

local function sh_ok(cmd)
	return sys.call(cmd .. " >/dev/null 2>&1") == 0
end

local function script_executable(path)
	return sys.call("[ -x " .. path .. " ] >/dev/null 2>&1") == 0
end

local function safe_port_str(s, fallback)
	local n = tonumber(s)
	if n and n >= 1 and n <= 65535 then
		return tostring(n)
	end
	return fallback
end

--- FORWARD DROP with comment privacy-killswitch-drop (iptables / xtables-nft / nft ruleset).
local function killswitch_drop_active_inline()
	if sh_ok("iptables -L FORWARD -n 2>/dev/null | grep -qF privacy-killswitch-drop") then
		return true
	end
	if sh_ok("iptables-save 2>/dev/null | grep -qF privacy-killswitch-drop") then
		return true
	end
	if sh_ok("nft list ruleset 2>/dev/null | grep -qF privacy-killswitch-drop") then
		return true
	end
	return false
end

local function killswitch_drop_active()
	if script_executable(KS_SCRIPT) then
		return sys.call(KS_SCRIPT .. " >/dev/null 2>&1") == 0
	end
	return killswitch_drop_active_inline()
end

local function tor_transparent_redirect_present_inline(trans_port, dns_port)
	local tp = safe_port_str(trans_port, "9040")
	local dp = safe_port_str(dns_port, "9053")
	if sh_ok("iptables -t nat -L PREROUTING -n 2>/dev/null | grep -q REDIRECT") then
		return true
	end
	if sh_ok("iptables-save -t nat 2>/dev/null | grep -qi REDIRECT") then
		return true
	end
	local nft = sys.exec("nft list ruleset 2>/dev/null")
	if type(nft) == "string" and nft ~= "" then
		local low = nft:lower()
		local has_redir = low:find("redirect", 1, true) or low:find("dnat", 1, true)
		if has_redir then
			local has_tp = nft:find(tp, 1, true) or low:find(":" .. tp, 1, true)
			local has_dp = nft:find(dp, 1, true) or low:find(":" .. dp, 1, true)
			if has_tp or has_dp then
				return true
			end
		end
	end
	return false
end

--- Tor transparent NAT: PREROUTING REDIRECT (iptables) or nft redirect/dnat to TransPort/DNSPort.
local function tor_transparent_redirect_present(trans_port, dns_port)
	local tp = safe_port_str(trans_port, "9040")
	local dp = safe_port_str(dns_port, "9053")
	if script_executable(TOR_SCRIPT) then
		return sys.call(TOR_SCRIPT .. " " .. tp .. " " .. dp .. " >/dev/null 2>&1") == 0
	end
	return tor_transparent_redirect_present_inline(trans_port, dns_port)
end

return {
	killswitch_drop_active = killswitch_drop_active,
	tor_transparent_redirect_present = tor_transparent_redirect_present,
}
