--[[
Shared IMEI page probes — same heuristics as rotate_imei.sh / former CBI.
]]

local sys = require "luci.sys"
local nixio_ok, nixio = pcall(require, "nixio")

local function can_read_dev(path)
	if not path or not path:match("^/dev/tty") then
		return false
	end
	if nixio_ok and nixio.fs and nixio.fs.access then
		return nixio.fs.access(path, "r")
	end
	return sys.call("test -r " .. path) == 0
end

local function collect_ttys()
	local out = {}
	local seen = {}
	local function add(p)
		if can_read_dev(p) and not seen[p] then
			seen[p] = true
			table.insert(out, p)
		end
	end
	for i = 0, 9 do
		add("/dev/ttyUSB" .. i)
	end
	for i = 0, 3 do
		add("/dev/ttyACM" .. i)
	end
	return out
end

local function sort_tty_prio(list)
	local pri = {
		["/dev/ttyUSB2"] = 1,
		["/dev/ttyUSB3"] = 2,
		["/dev/ttyUSB1"] = 3,
		["/dev/ttyUSB0"] = 4,
	}
	table.sort(list, function(a, b)
		local pa, pb = pri[a] or 50, pri[b] or 50
		if pa ~= pb then
			return pa < pb
		end
		return a < b
	end)
end

local function preferred_modem_tty(tty_scan)
	for _, p in ipairs(tty_scan) do
		return p
	end
	return nil
end

local function list_network_interfaces(uc)
	local out = {}
	uc:foreach("network", "interface", function(s)
		local name = s[".name"]
		if name and name ~= "loopback" then
			table.insert(out, name)
		end
	end)
	table.sort(out)
	return out
end

local function network_wwan_candidates(uc)
	local c = {}
	local seen = {}
	local function add(name)
		if name and name ~= "" and not seen[name] then
			seen[name] = true
			table.insert(c, name)
		end
	end
	for _, name in ipairs({ "wwan", "4g", "modem", "cellular" }) do
		if uc:get("network", name) then
			add(name)
		end
	end
	uc:foreach("network", "interface", function(s)
		local name = s[".name"]
		local proto = uc:get("network", name, "proto") or ""
		if proto:match("wwan") or proto == "3g" or proto == "mbim" or proto == "qmi" or proto == "ncm" then
			add(name)
		end
	end)
	return c
end

local function preferred_wwan(uc)
	local list = network_wwan_candidates(uc)
	if #list > 0 then
		return list[1]
	end
	return nil
end

local function copy_tbl(t)
	local o = {}
	for i, v in ipairs(t) do
		o[i] = v
	end
	return o
end

--- @return table preview for IMEI template / controller
local function get_preview()
	local tty_scan = collect_ttys()
	sort_tty_prio(tty_scan)
	local tty_list = copy_tbl(tty_scan)

	local uc = require "luci.model.uci".cursor()
	local iface_list = list_network_interfaces(uc)
	local wwan_scan = network_wwan_candidates(uc)
	local slug = uc:get("glinet_privacy", "hw", "slug") or ""

	return {
		tty_scan = tty_list,
		iface_list = iface_list,
		wwan_scan = wwan_scan,
		slug = slug,
		preferred_modem = preferred_modem_tty(tty_list),
		preferred_wwan = preferred_wwan(uc),
	}
end

return {
	get_preview = get_preview,
	collect_ttys = collect_ttys,
	sort_tty_prio = sort_tty_prio,
}
