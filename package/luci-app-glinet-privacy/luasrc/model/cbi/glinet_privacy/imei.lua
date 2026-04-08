--[[
IMEI rotation — UCI: rotate_imei
Prepopulates modem TTY and WWAN interface from local hardware / network config (same heuristics as /usr/bin/rotate_imei.sh).
]]

local i18n = require "luci.glinet_privacy.i18n"
local translate = i18n.translate
local translatef = i18n.translatef or function(fmt, ...)
	return translate(string.format(fmt, ...))
end
local sys = require "luci.sys"

local nixio_ok, nixio = pcall(require, "nixio")

---@param path string
---@return boolean
local function can_read_dev(path)
	if not path or not path:match("^/dev/tty") then
		return false
	end
	if nixio_ok and nixio.fs and nixio.fs.access then
		return nixio.fs.access(path, "r")
	end
	return sys.call("test -r " .. path) == 0
end

--- Same probe order as rotate_imei.sh find_modem_tty() after explicit MODEM_TTY.
---@return string[]
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

--- Prefer ttyUSB2, ttyUSB3, ttyUSB1, ttyUSB0, then remaining sorted by name.
---@param list string[]
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

---@return string|nil
local function preferred_modem_tty()
	local list = collect_ttys()
	sort_tty_prio(list)
	if #list > 0 then
		return list[1]
	end
	return nil
end

--- All logical interface names from UCI network (config interface …), except loopback.
---@param uc luci.model.uci.cursor
---@return string[]
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

---@param uc luci.model.uci.cursor
---@return string[]
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

---@param uc luci.model.uci.cursor
---@return string|nil
local function preferred_wwan(uc)
	local list = network_wwan_candidates(uc)
	if #list > 0 then
		return list[1]
	end
	return nil
end

local tty_scan = collect_ttys()
sort_tty_prio(tty_scan)

local uc_preview = require "luci.model.uci".cursor()
local iface_list = list_network_interfaces(uc_preview)
local wwan_scan = network_wwan_candidates(uc_preview)
local slug_preview = uc_preview:get("glinet_privacy", "hw", "slug") or ""

m = Map("rotate_imei", translate("IMEI rotation"),
	translate("Boot-time or cron rotation for Quectel modems via AT+EGMR. Altering IMEI may be unlawful outside operator-authorized or lab use; you are responsible for compliance. See docs/devices.md (IMEI section) in the project repository. Firmware may reject writes. Optional: set ROTATE_IMEI_SUPPRESS_LEGAL_LOG=1 on cron after you have verified compliance."))

s = m:section(NamedSection, "main", "rotate_imei", translate("Settings"))
s.addremove = false

local hint = s:option(DummyValue, "_detection", translate("Auto-detection"))
hint.rawhtml = true
function hint.cfgvalue(self, section)
	local parts = {}
	if slug_preview ~= "" then
		table.insert(parts, translatef("Device profile: %s", slug_preview))
	end
	if slug_preview == "puli_xe300" then
		table.insert(parts, translate("Cellular (Puli) — IMEI rotation applies when modem is present."))
	elseif slug_preview == "slate_ax1800" or slug_preview == "gl_ax1800" or slug_preview == "generic" then
		table.insert(parts, translate("Travel router profile — no built-in modem; leave rotation off unless you use USB cellular."))
	end
	if #tty_scan > 0 then
		table.insert(parts, translatef("Serial ports found: %s", table.concat(tty_scan, ", ")))
	else
		table.insert(parts, translate("No readable /dev/ttyUSB* or /dev/ttyACM* — modem not connected or permissions."))
	end
	if #iface_list > 0 then
		table.insert(parts, translatef("Network interfaces (uci): %s", table.concat(iface_list, ", ")))
	else
		table.insert(parts, translate("No network interfaces in UCI."))
	end
	return table.concat(parts, "<br />")
end

s:option(Flag, "enabled", translate("Run on boot"),
	translate("Uses /etc/init.d/rotate_imei when enabled.")).rmempty = false

s:option(Flag, "cron_enabled", translate("Cron: rotate on a schedule"),
	translate("Adds one line to /etc/crontabs/root for /usr/bin/rotate_imei.sh. Requires a system cron daemon (scheduled tasks). Interval is configured below.")).rmempty = false

local cron_iv = s:option(ListValue, "cron_interval_hours", translate("Hours between cron rotations"),
	translate("Crontab runs at minute 0 each period (1 = every hour at :00; 24 = once daily at midnight; other values use 0 */N * * *)."))
for i = 1, 24 do
	cron_iv:value(tostring(i))
end
cron_iv.default = "6"
cron_iv:depends("cron_enabled", "1")

local cron_sup = s:option(Flag, "cron_suppress_legal_log", translate("Suppress legal notice in syslog (cron)"),
	translate("Prefixes the cron command with ROTATE_IMEI_SUPPRESS_LEGAL_LOG=1 (use only after you have verified legal compliance)."))
cron_sup.rmempty = false
cron_sup:depends("cron_enabled", "1")

local modem_tty = s:option(ListValue, "modem_tty", translate("Modem serial device"),
	translate("AT port for Quectel (often ttyUSB2). Empty = same scan order as rotate_imei.sh."))
modem_tty:value("", translate("Auto (scan /dev/ttyUSB* then /dev/ttyACM*)"))
for _, dev in ipairs(tty_scan) do
	modem_tty:value(dev)
end
do
	local saved_mt = uc_preview:get("rotate_imei", "main", "modem_tty") or ""
	if saved_mt ~= "" then
		local found = false
		for _, d in ipairs(tty_scan) do
			if d == saved_mt then
				found = true
				break
			end
		end
		if not found then
			modem_tty:value(saved_mt, saved_mt .. " (" .. translate("saved") .. ")")
		end
	end
end
function modem_tty.cfgvalue(self, section)
	local v = self.map.uci:get("rotate_imei", "main", "modem_tty") or ""
	if v ~= "" then
		return v
	end
	return preferred_modem_tty() or ""
end

local wwan_if = s:option(ListValue, "wwan_if", translate("WWAN logical interface"),
	translate("Which Network → Interfaces section to restart after IMEI write. Empty = same auto-detect as rotate_imei.sh (wwan / 4g / modem / cellular, or first wwan/3g/qmi/mbim/ncm)."))
wwan_if:value("", translate("Auto (from network config)"))
for _, name in ipairs(iface_list) do
	wwan_if:value(name)
end
do
	local saved_w = uc_preview:get("rotate_imei", "main", "wwan_if") or ""
	if saved_w ~= "" then
		local found = false
		for _, n in ipairs(iface_list) do
			if n == saved_w then
				found = true
				break
			end
		end
		if not found then
			wwan_if:value(saved_w, saved_w .. " (" .. translate("saved") .. ")")
		end
	end
end
function wwan_if.cfgvalue(self, section)
	local v = self.map.uci:get("rotate_imei", "main", "wwan_if") or ""
	if v ~= "" then
		return v
	end
	return preferred_wwan(self.map.uci) or ""
end

function m.on_commit(self)
	sys.call("/etc/init.d/rotate_imei enable 2>/dev/null")
	sys.call("/usr/libexec/glinet-privacy/apply-rotate-imei-cron.sh 2>/dev/null || true")
end

return m
