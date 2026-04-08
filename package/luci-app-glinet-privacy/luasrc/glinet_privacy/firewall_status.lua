--[[
SPDX-License-Identifier: GPL-2.0-only
Copyright (c) 2026 GL.iNet Privacy contributors
Status probes for killswitch + Tor NAT when only iptables-nft or raw nft tooling reflects reality.
]]

local sys = require "luci.sys"

local function sh_ok(cmd)
	return sys.call(cmd .. " >/dev/null 2>&1") == 0
end

--- FORWARD DROP with comment privacy-killswitch-drop (iptables / xtables-nft / nft ruleset).
local function killswitch_drop_active()
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

--- Tor transparent NAT: PREROUTING REDIRECT (iptables) or nft redirect/dnat to TransPort/DNSPort.
--- @param trans_port string|number e.g. 9040
--- @param dns_port string|number e.g. 9053
local function tor_transparent_redirect_present(trans_port, dns_port)
	local tp = tostring(trans_port or "9040")
	local dp = tostring(dns_port or "9053")
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

return {
	killswitch_drop_active = killswitch_drop_active,
	tor_transparent_redirect_present = tor_transparent_redirect_present,
}
