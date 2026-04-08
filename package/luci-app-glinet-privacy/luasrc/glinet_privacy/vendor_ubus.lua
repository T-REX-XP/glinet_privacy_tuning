--[[
Read-only ubus snapshots for LuCI (VPN/DNS context). Opt-in + optional version gate; see docs/vendor-ubus.md.
Only invocations listed in docs/vendor-ubus.md are executed; object/interface names are never taken from HTTP input.
]]

local sys = require "luci.sys"

local function tr(s)
	local ok, i18n = pcall(require, "luci.glinet_privacy.i18n")
	if ok and i18n and i18n.translate then
		return i18n.translate(s)
	end
	return s
end

local MAX_CHARS = 2200

local function yn(v)
	return v == "1" or v == "true" or v == "yes" or v == "on"
end

local function trim_out(s)
	if type(s) ~= "string" then
		return ""
	end
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	if #s > MAX_CHARS then
		return s:sub(1, MAX_CHARS) .. "\n…"
	end
	return s
end

local function parse_json(raw)
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
	return nil
end

local function board_release_blob(t)
	if type(t) ~= "table" then
		return ""
	end
	local r = t.release
	if type(r) ~= "table" then
		return ""
	end
	local parts = {
		tostring(r.description or ""),
		tostring(r.version or ""),
		tostring(r.revision or ""),
		tostring(r.distversion or ""),
	}
	return table.concat(parts, " ")
end

--- UCI network interface section: alphanumeric + underscore only.
local function net_section_uci(name)
	if type(name) ~= "string" or not name:match("^[%w_]+$") or #name > 32 then
		return nil
	end
	return name
end

local function first_wanish_iface(uc)
	for _, sid in ipairs({ "wan", "wwan", "modem" }) do
		local s = net_section_uci(sid)
		if
			s
			and (
				uc:get("network", s, "proto")
				or uc:get("network", s, "device")
				or uc:get("network", s, "ifname")
			)
		then
			return s
		end
	end
	return nil
end

--- @param title string translated short heading
--- @param run fun(): string, string|nil
local function probe_run(id, title, run)
	local ok, pack = pcall(function()
		local out, cmd = run()
		return { out = out or "", cmd = cmd }
	end)
	if not ok then
		return {
			id = id,
			title = title,
			ok = false,
			output = "",
			error = tostring(pack or "?"),
		}
	end
	pack = pack or {}
	return {
		id = id,
		title = title,
		ok = true,
		output = trim_out(pack.out),
		cmd = pack.cmd,
	}
end

local function snapshot()
	local uc = require "luci.model.uci".cursor()
	if not uc:get_all("glinet_privacy") then
		return { active = false }
	end
	local vu = "vendor_ubus"
	if not yn(uc:get("glinet_privacy", vu, "enabled")) then
		return { active = false }
	end

	local raw_board = sys.exec("ubus call system board 2>/dev/null") or ""

	local gate = uc:get("glinet_privacy", vu, "min_release_substr") or ""
	if type(gate) ~= "string" then
		gate = ""
	end

	local board_t = parse_json(raw_board)
	local rel = board_release_blob(board_t or {})
	local gated = false
	local gate_reason = nil
	if gate ~= "" then
		if not raw_board:find(gate, 1, true) then
			gated = true
			gate_reason = "min_release_substr"
		end
	end

	local probes = {}
	local function add(p)
		probes[#probes + 1] = p
	end

	-- Always fetch board first for UI / gate message; probes below may be skipped when gated.
	add(probe_run("system_board", tr("System board (ubus)"), function()
		local cmd = "ubus call system board 2>/dev/null"
		return raw_board, cmd
	end))

	if not gated then
		local ifn = first_wanish_iface(uc)
		if ifn then
			add(probe_run("network_iface", tr("Primary WAN-class interface (ubus)"), function()
				local cmd = "ubus call network.interface." .. ifn .. " status 2>/dev/null"
				return sys.exec(cmd) or "", cmd
			end))
		else
			add({
				id = "network_iface",
				title = tr("Primary WAN-class interface (ubus)"),
				ok = true,
				output = "",
				cmd = nil,
				skipped = tr("No WAN / WWAN / modem network section in UCI."),
			})
		end

		add(probe_run("dhcp_ipv4leases", tr("DHCP IPv4 leases (ubus)"), function()
			local cmd = "ubus call dhcp ipv4leases 2>/dev/null"
			return sys.exec(cmd) or "", cmd
		end))
	end

	return {
		active = true,
		gated = gated,
		gate_substr = gate,
		gate_reason = gate_reason,
		board_release = trim_out(rel),
		probes = probes,
		doc_hint = "vendor-ubus.md",
	}
end

return {
	snapshot = snapshot,
}
