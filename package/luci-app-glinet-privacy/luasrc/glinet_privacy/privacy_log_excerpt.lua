--[[
SPDX-License-Identifier: GPL-2.0-only
Copyright (c) 2026 GL.iNet Privacy contributors
Recent syslog lines from logread(1), filtered to this project’s logger tags (watchdog, scripts).
]]

local sys = require "luci.sys"

--- Match logger -t tags used by package/glinet-privacy shell scripts.
local LINE_PATTERNS = {
	"privacy%-ks",
	"glinet%-telemetry",
	"glinet%-vendor%-ks",
	"glinet%-dns%-policy",
	"rotate_imei",
}

local function line_matches(line)
	if type(line) ~= "string" or line == "" then
		return false
	end
	for _, p in ipairs(LINE_PATTERNS) do
		if line:match(p) then
			return true
		end
	end
	return false
end

local function escape_attr_title(s)
	if type(s) ~= "string" or s == "" then
		return ""
	end
	s = s:gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;")
	s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
	s = s:gsub("\n+", " · ")
	if #s > 1600 then
		s = s:sub(1, 1597) .. "…"
	end
	return s
end

local TAIL_LINES = 320
local MAX_EXCERPT = 14
local DISPLAY_LAST_MAX = 96

--- @return table { lines = string[], last_line = string, tooltip_title = string, empty = bool }
local function snapshot()
	local raw = sys.exec("logread 2>/dev/null | tail -"
		.. tostring(TAIL_LINES)
		.. " 2>/dev/null") or ""
	local matched = {}
	for line in raw:gmatch("[^\r\n]+") do
		if line_matches(line) then
			table.insert(matched, line)
		end
	end

	if #matched == 0 then
		return {
			lines = {},
			last_line = "",
			last_line_full = "",
			tooltip_title = "",
			empty = true,
		}
	end

	local start = math.max(1, #matched - (MAX_EXCERPT - 1))
	local excerpt = {}
	for i = start, #matched do
		table.insert(excerpt, matched[i])
	end

	local last_full = matched[#matched] or ""
	local last_show = last_full
	if #last_show > DISPLAY_LAST_MAX then
		last_show = last_show:sub(1, DISPLAY_LAST_MAX - 1) .. "…"
	end

	local tip_parts = {}
	for i = math.max(1, #excerpt - 7), #excerpt do
		table.insert(tip_parts, excerpt[i])
	end
	local tooltip = escape_attr_title(table.concat(tip_parts, "\n"))

	return {
		lines = excerpt,
		last_line = last_show,
		last_line_full = last_full,
		tooltip_title = tooltip,
		empty = false,
	}
end

return {
	snapshot = snapshot,
}
