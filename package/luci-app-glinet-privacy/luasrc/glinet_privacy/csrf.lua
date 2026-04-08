--[[
SPDX-License-Identifier: GPL-2.0-only
Copyright (c) 2026 GL.iNet Privacy contributors
CSRF for custom HTML forms: hidden field "token" must match the LuCI session authtoken
(same model as stock luci.dispatcher.test_post_security in luci-lua-runtime).
Uses luci.http only — avoids _G.L.http vs classic module mismatch on mixed images.
]]

local http = require "luci.http"
local disp = require "luci.dispatcher"

local function authtoken()
	local ctx = disp.context
	if type(ctx) == "table" and ctx.authtoken then
		return ctx.authtoken
	end
	if _G.L and type(_G.L.ctx) == "table" and _G.L.ctx.authtoken then
		return _G.L.ctx.authtoken
	end
	return nil
end

local function write_csrf_error_body()
	http.prepare_content("text/html; charset=UTF-8")
	local tpl = require "luci.template"
	local ok = pcall(function()
		tpl.render("csrftoken")
	end)
	if not ok then
		http.write("<p>Invalid security token. Reload the administration page and try again.</p>")
	end
end

--- Value for hidden input name="token" (empty if no session context).
local function token_for_template()
	return authtoken() or ""
end

--- Require POST and valid "token" matching session authtoken.
--- @return boolean
local function verify_post()
	if http.getenv("REQUEST_METHOD") ~= "POST" then
		http.status(405, "Method Not Allowed")
		http.header("Allow", "POST")
		return false
	end

	local expect = authtoken()
	local posted = http.formvalue("token")
	if type(posted) == "table" then
		posted = posted[#posted]
	end

	if not expect then
		http.status(403, "Forbidden")
		write_csrf_error_body()
		return false
	end

	if type(posted) ~= "string" or posted ~= expect then
		http.status(403, "Forbidden")
		write_csrf_error_body()
		return false
	end

	return true
end

return {
	token_for_template = token_for_template,
	verify_post = verify_post,
}
