--[[
Harden user/UCI strings before shell interpolation or UCI commit (defense-in-depth).
IFNAMSIZ on Linux is 16 bytes including trailing NUL => 15 printable chars max.
]]

local IFNAME_MAX = 15
local IFNAME_RE = "^[a-zA-Z0-9._-]+$"

local function valid_ifname(s)
	if type(s) ~= "string" or s == "" then
		return false
	end
	if #s > IFNAME_MAX then
		return false
	end
	return s:match(IFNAME_RE) ~= nil
end

--- @return string|nil  nil if invalid (do not use in shell)
local function sanitize_ifname(s)
	if valid_ifname(s) then
		return s
	end
	return nil
end

--- Empty string is valid (means “auto” in several UCI options).
--- @return string|nil  nil if non-empty but invalid
local function sanitize_ifname_or_empty(s)
	if s == nil or s == "" then
		return ""
	end
	if valid_ifname(s) then
		return s
	end
	return nil
end

--- Modem serial device path (rotate_imei).
local function valid_modem_tty(s)
	if s == nil or s == "" then
		return true
	end
	if #s > 64 then
		return false
	end
	return s:match("^/dev/tty[A-Za-z0-9._-]+$") ~= nil
end

local function sanitize_modem_tty(s)
	if s == nil or s == "" then
		return ""
	end
	if valid_modem_tty(s) then
		return s
	end
	return nil
end

local function valid_ipv4(s)
	if type(s) ~= "string" or s == "" then
		return false
	end
	local a, b, c, d = s:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
	if not a then
		return false
	end
	for _, x in ipairs({ a, b, c, d }) do
		local n = tonumber(x)
		if not n or n < 0 or n > 255 then
			return false
		end
	end
	return true
end

local function valid_lan_cidr(s)
	if type(s) ~= "string" or s == "" then
		return false
	end
	local a, b, c, d, p = s:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)/(%d+)$")
	if not a then
		return false
	end
	if not valid_ipv4(string.format("%s.%s.%s.%s", a, b, c, d)) then
		return false
	end
	p = tonumber(p)
	return p ~= nil and p >= 0 and p <= 32
end

local function sanitize_port_str(s, default_port)
	if type(s) ~= "string" or s == "" then
		return tostring(default_port)
	end
	local n = tonumber(s)
	if not n or n < 1 or n > 65535 or math.floor(n) ~= n then
		return nil
	end
	return tostring(n)
end

return {
	valid_ifname = valid_ifname,
	sanitize_ifname = sanitize_ifname,
	sanitize_ifname_or_empty = sanitize_ifname_or_empty,
	valid_modem_tty = valid_modem_tty,
	sanitize_modem_tty = sanitize_modem_tty,
	valid_ipv4 = valid_ipv4,
	valid_lan_cidr = valid_lan_cidr,
	sanitize_port_str = sanitize_port_str,
	IFNAME_MAX = IFNAME_MAX,
}
