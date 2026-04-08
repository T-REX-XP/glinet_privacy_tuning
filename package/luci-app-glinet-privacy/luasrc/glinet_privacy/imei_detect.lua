--[[
SPDX-License-Identifier: GPL-2.0-only
Copyright (c) 2026 GL.iNet Privacy contributors
Shared IMEI page probes — same heuristics as rotate_imei.sh / former CBI.
]]

local sys = require "luci.sys"
local nixio_ok, nixio = pcall(require, "nixio")

local function tr(s)
	local ok, i18n = pcall(require, "luci.glinet_privacy.i18n")
	if ok and i18n and i18n.translate then
		return i18n.translate(s)
	end
	return s
end

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

local function trim_str(s, max)
	if type(s) ~= "string" then
		return ""
	end
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	if max and #s > max then
		return s:sub(1, max) .. "…"
	end
	return s
end

local function cmd_ok(name)
	if type(name) ~= "string" or not name:match("^%a[%w_-]*$") then
		return false
	end
	return sys.call("command -v " .. name .. " >/dev/null 2>&1") == 0
end

local function chr_dev_exists(path)
	if type(path) ~= "string" or not path:match("^/dev/cdc%-wdm[0-9]+$") then
		return false
	end
	return sys.call("test -c " .. path .. " 2>/dev/null") == 0
end

local function uci_cdc_wdm_devices(uc)
	local out = {}
	local seen = {}
	local function add(p)
		if chr_dev_exists(p) and not seen[p] then
			seen[p] = true
			table.insert(out, p)
		end
	end
	uc:foreach("network", "interface", function(s)
		local name = s[".name"]
		local d = uc:get("network", name, "device") or ""
		add(d)
	end)
	for i = 0, 9 do
		add("/dev/cdc-wdm" .. i)
	end
	return out
end

--- Read-only **mmcli** / **uqmi** snippets when binaries exist (no AT side effects).
--- @param uc_opt luci.model.uci.cursor|nil  optional; used to find **`network.*.device`** QMI paths
local function get_mmcli_uqmi_hints(uc_opt)
	local hints = {
		mmcli_present = false,
		mmcli_summary = "",
		uqmi_present = false,
		uqmi_summary = "",
	}

	if cmd_ok("mmcli") then
		hints.mmcli_present = true
		local list = sys.exec("mmcli -L 2>/dev/null") or ""
		list = trim_str(list, 1400)
		local blocks = {}
		if list ~= "" then
			blocks[#blocks + 1] = "mmcli -L:\n" .. list
		end
		if not list:match("No modems") and list ~= "" then
			local m0 = sys.exec("mmcli -m 0 2>/dev/null") or ""
			m0 = trim_str(m0, 1200)
			if m0 ~= "" then
				blocks[#blocks + 1] = "mmcli -m 0:\n" .. m0
			end
		end
		if #blocks == 0 then
			hints.mmcli_summary = tr("(no mmcli output — ModemManager may be inactive)")
		else
			hints.mmcli_summary = table.concat(blocks, "\n\n")
		end
	end

	if cmd_ok("uqmi") then
		hints.uqmi_present = true
		local ucur = uc_opt or require "luci.model.uci".cursor()
		local lines = {}
		for _, dev in ipairs(uci_cdc_wdm_devices(ucur)) do
			local imei = sys.exec("uqmi -d " .. dev .. " --get-imei 2>/dev/null") or ""
			imei = trim_str(imei, 32):gsub("%s+", "")
			local ss = sys.exec("uqmi -d " .. dev .. " --get-serving-system 2>/dev/null") or ""
			ss = trim_str(ss, 200)
			if imei ~= "" then
				lines[#lines + 1] = dev .. ": IMEI " .. imei
			elseif ss ~= "" then
				lines[#lines + 1] = dev .. ": " .. ss
			else
				lines[#lines + 1] = dev .. ": " .. tr("(no data — wrong QMI device or busy)")
			end
		end
		if #lines == 0 then
			hints.uqmi_summary = tr("(no /dev/cdc-wdm* character device — check WWAN UCI device path)")
		else
			hints.uqmi_summary = table.concat(lines, "\n")
		end
	end

	return hints
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

	local mm_hints = get_mmcli_uqmi_hints(uc)

	return {
		tty_scan = tty_list,
		iface_list = iface_list,
		wwan_scan = wwan_scan,
		slug = slug,
		preferred_modem = preferred_modem_tty(tty_list),
		preferred_wwan = preferred_wwan(uc),
		mm_hints = mm_hints,
	}
end

return {
	get_preview = get_preview,
	get_mmcli_uqmi_hints = get_mmcli_uqmi_hints,
	collect_ttys = collect_ttys,
	sort_tty_prio = sort_tty_prio,
}
