--[[
LuCI: GL.iNet Privacy — Services menu
]]

module("luci.controller.glinet_privacy", package.seeall)

-- ucode-based LuCI does not inject translate/translatef; load catalog and bind from luci.i18n.
local i18n = require "luci.glinet_privacy.i18n"
local translate = i18n.translate
local translatef = i18n.translatef or function(fmt, ...)
	return i18n.translate(string.format(fmt, ...))
end

function index()
	entry({"admin", "services", "glinet_privacy"},
		alias("admin", "services", "glinet_privacy", "overview"),
		translate("GL.iNet Privacy"), 60)

	entry({"admin", "services", "glinet_privacy", "overview"},
		call("action_overview"), translate("Overview"), 1)
	entry({"admin", "services", "glinet_privacy", "killswitch"},
		call("action_killswitch"), translate("Kill switch"), 2)
	entry({"admin", "services", "glinet_privacy", "imei"},
		call("action_imei"), translate("IMEI rotation"), 3)
	entry({"admin", "services", "glinet_privacy", "plugins"},
		call("action_tor_dns"), translate("Tor, DNS & telemetry"), 4)
	entry({"admin", "services", "glinet_privacy", "verify"},
		call("action_verify"), translate("Verify"), 5)
end

local function sh_ok(cmd)
	return luci.sys.call(cmd .. " >/dev/null 2>&1") == 0
end

function build_status()
	local uci = require "luci.model.uci".cursor()
	local items = {}
	local ok_c, problem_c, skip_c = 0, 0, 0

	-- toggle: form field name (e.g. f_require_wg) rendered as switch on Overview, or nil
	local function add(id, label, detail, state, toggle)
		table.insert(items, {
			id = id,
			label = label,
			detail = detail or "",
			state = state,
			toggle = toggle or nil
		})
		if state == "ok" then
			ok_c = ok_c + 1
		elseif state == "skip" then
			skip_c = skip_c + 1
		else
			problem_c = problem_c + 1
		end
	end

	local slug = uci:get("glinet_privacy", "hw", "slug") or "?"
	add("profile", translate("Device profile"), slug, "ok")

	if uci:get("firewall", "glinet_privacy", "path") then
		add("fw_inc", translate("Firewall plugin"), translate("Registered"), "ok")
	else
		add("fw_inc", translate("Firewall plugin"), translate("Missing UCI firewall.glinet_privacy"), "bad")
	end

	local wg_if = uci:get("privacy", "main", "wg_if") or "wg0"
	local req_wg = uci:get("privacy", "main", "require_wg") or "1"
	if req_wg == "0" then
		add("wg", translatef("WireGuard (%s)", wg_if), translate("Not required"), "skip", "f_require_wg")
	elseif sh_ok("ip link show " .. wg_if .. " 2>/dev/null | grep -q 'state UP'") then
		add("wg", translatef("WireGuard (%s)", wg_if), translate("Interface up"), "ok", "f_require_wg")
	else
		add("wg", translatef("WireGuard (%s)", wg_if), translate("Down or missing"), "bad", "f_require_wg")
	end

	local req_tor = uci:get("privacy", "main", "require_tor") or "1"
	if req_tor == "0" then
		add("tor_proc", translate("Tor daemon"), translate("Not required by kill switch"), "skip", "f_require_tor")
	elseif sh_ok("pidof tor") then
		add("tor_proc", translate("Tor daemon"), translate("Running"), "ok", "f_require_tor")
	else
		add("tor_proc", translate("Tor daemon"), translate("Not running"), "bad", "f_require_tor")
	end

	local tt = uci:get("glinet_privacy", "tor", "tor_transparent") or "0"
	if tt == "1" then
		if sh_ok("iptables -t nat -L PREROUTING -n 2>/dev/null | grep -q REDIRECT") then
			add("tor_nat", translate("Tor transparent NAT"), translate("REDIRECT rules present"), "ok", "f_tor_transparent")
		else
			add("tor_nat", translate("Tor transparent NAT"), translate("UCI enabled; no REDIRECT in NAT table"), "warn", "f_tor_transparent")
		end
	else
		add("tor_nat", translate("Tor transparent NAT"), translate("Disabled"), "skip", "f_tor_transparent")
	end

	local ks_en = uci:get("privacy", "main", "enabled") or "1"
	if ks_en == "1" then
		if sh_ok("iptables -L FORWARD -n 2>/dev/null | grep -q privacy-killswitch-drop") then
			add("ks", translate("Kill switch"), translate("Emergency DROP active (VPN/Tor unhealthy?)"), "warn", "f_privacy_enabled")
		else
			add("ks", translate("Kill switch"), translate("Watchdog active; no DROP (healthy)"), "ok", "f_privacy_enabled")
		end
	else
		add("ks", translate("Kill switch"), translate("Disabled"), "skip", "f_privacy_enabled")
	end

	if sh_ok("grep -q privacy-killswitch-watchdog /etc/crontabs/root 2>/dev/null") then
		add("cron", translate("Cron watchdog"), translate("Scheduled"), "ok")
	else
		add("cron", translate("Cron watchdog"), translate("No crontab line"), "warn")
	end

	local blk = uci:get("glinet_privacy", "tel", "block_domains") or "0"
	if blk == "1" then
		add("tel", translate("Telemetry DNS block"), translate("Enabled"), "ok", "f_block_domains")
	else
		add("tel", translate("Telemetry DNS block"), translate("Off"), "skip", "f_block_domains")
	end

	if sh_ok("opkg list-installed 2>/dev/null | grep -q '^tor '") or sh_ok("command -v tor") then
		add("pkg_tor", translate("tor package / binary"), translate("Present"), "ok")
	else
		add("pkg_tor", translate("tor package / binary"), translate("Missing"), "warn")
	end

	local dis_v = uci:get("glinet_privacy", "tel", "disable_vendor_cloud") or "0"
	if dis_v == "1" then
		add("vendor_cloud", translate("GL.iNet cloud"), translate("Disabled"), "ok", "f_disable_vendor")
	else
		add("vendor_cloud", translate("GL.iNet cloud"), translate("Active"), "skip", "f_disable_vendor")
	end

	local rcp = uci:get("glinet_privacy", "tel", "remove_cloud_packages") or "0"
	if rcp == "1" then
		add("cloud_pkgs", translate("Cloud packages (opkg)"), translate("Removal enabled"), "ok", "f_remove_cloud_pkgs")
	else
		add("cloud_pkgs", translate("Cloud packages (opkg)"), translate("Installed"), "skip", "f_remove_cloud_pkgs")
	end

	if uci:get_all("rotate_imei") then
		local ri_en = uci:get("rotate_imei", "main", "enabled") or "0"
		if ri_en == "1" then
			add("imei", translate("IMEI rotation"), translate("Enabled on boot"), "ok", "f_rotate_imei")
		else
			add("imei", translate("IMEI rotation"), translate("Disabled"), "skip", "f_rotate_imei")
		end
	end

	local denom = ok_c + problem_c
	local pct = 0
	if denom > 0 then
		pct = math.floor(100 * ok_c / denom)
	end

	return {
		items = items,
		pct = pct,
		ok_c = ok_c,
		problem_c = problem_c,
		skip_c = skip_c,
		denom = denom
	}
end

function action_overview()
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()
	local disp = require "luci.dispatcher"
	local sys = require "luci.sys"

	if http.formvalue("submit_settings") == "1" then
		local function yn(name)
			local v = http.formvalue(name)
			if type(v) == "table" then
				v = v[#v]
			end
			return v == "1" and "1" or "0"
		end

		uci:set("privacy", "main", "enabled", yn("f_privacy_enabled"))
		uci:set("privacy", "main", "require_wg", yn("f_require_wg"))
		uci:set("privacy", "main", "require_tor", yn("f_require_tor"))
		uci:set("glinet_privacy", "tor", "tor_transparent", yn("f_tor_transparent"))
		uci:set("glinet_privacy", "tel", "block_domains", yn("f_block_domains"))
		uci:set("glinet_privacy", "tel", "disable_vendor_cloud", yn("f_disable_vendor"))
		uci:set("glinet_privacy", "tel", "remove_cloud_packages", yn("f_remove_cloud_pkgs"))

		local ri_changed = false
		-- Only touch rotate_imei when the Overview row was rendered (field present in POST).
		if uci:get_all("rotate_imei") and http.formvalue("f_rotate_imei") ~= nil then
			uci:foreach("rotate_imei", "rotate_imei", function(s)
				uci:set("rotate_imei", s[".name"], "enabled", yn("f_rotate_imei"))
				ri_changed = true
			end)
		end

		uci:commit("privacy")
		uci:commit("glinet_privacy")
		if ri_changed then
			uci:commit("rotate_imei")
		end

		sys.call("/usr/bin/privacy-killswitch-watchdog.sh >/dev/null 2>&1")
		sys.call("/usr/libexec/glinet-privacy/apply-telemetry.sh >/dev/null 2>&1")
		sys.call("/etc/init.d/firewall reload >/dev/null 2>&1")
		sys.call("/etc/init.d/dnsmasq restart >/dev/null 2>&1")
		if luci.sys.call("test -x /usr/libexec/glinet-privacy/apply-rotate-imei-cron.sh") == 0 then
			sys.call("/usr/libexec/glinet-privacy/apply-rotate-imei-cron.sh >/dev/null 2>&1 || true")
		end

		luci.http.redirect(disp.build_url("admin/services/glinet_privacy/overview"))
		return
	end

	local st = build_status()
	local form = {
		f_privacy_enabled = uci:get("privacy", "main", "enabled") or "1",
		f_require_wg = uci:get("privacy", "main", "require_wg") or "1",
		f_require_tor = uci:get("privacy", "main", "require_tor") or "1",
		f_tor_transparent = uci:get("glinet_privacy", "tor", "tor_transparent") or "0",
		f_block_domains = uci:get("glinet_privacy", "tel", "block_domains") or "0",
		f_disable_vendor = uci:get("glinet_privacy", "tel", "disable_vendor_cloud") or "0",
		f_remove_cloud_pkgs = uci:get("glinet_privacy", "tel", "remove_cloud_packages") or "0",
		f_rotate_imei = "0",
		has_rotate_imei = false
	}
	if uci:get_all("rotate_imei") then
		form.has_rotate_imei = true
		form.f_rotate_imei = uci:get("rotate_imei", "main", "enabled") or "0"
	end

	local net = require("luci.glinet_privacy.net_probe").snapshot()

	luci.template.render("glinet_privacy/overview", {
		status = st,
		form = form,
		net = net,
	})
end

function action_killswitch()
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()
	local disp = require "luci.dispatcher"
	local sys = require "luci.sys"

	local function yn(name)
		local v = http.formvalue(name)
		if type(v) == "table" then
			v = v[#v]
		end
		return v == "1" and "1" or "0"
	end

	local function str1(name)
		local v = http.formvalue(name)
		if type(v) == "table" then
			v = v[#v]
		end
		if type(v) ~= "string" then
			return ""
		end
		return v:gsub("^%s+", ""):gsub("%s+$", "")
	end

	if http.formvalue("submit") == "1" then
		uci:set("privacy", "main", "enabled", yn("enabled"))
		local wg = str1("wg_if")
		if wg == "" then
			wg = "wg0"
		end
		uci:set("privacy", "main", "wg_if", wg)
		uci:set("privacy", "main", "require_wg", yn("require_wg"))
		uci:set("privacy", "main", "require_tor", yn("require_tor"))
		uci:set("privacy", "main", "lan_dev", str1("lan_dev"))
		uci:set("privacy", "main", "wan_dev", str1("wan_dev"))
		local vk = str1("vendor_gl_vpn_killswitch")
		if vk ~= "on" and vk ~= "off" and vk ~= "leave" then
			vk = "leave"
		end
		uci:set("privacy", "main", "vendor_gl_vpn_killswitch", vk)
		uci:commit("privacy")
		sys.call("/usr/libexec/glinet-privacy/apply-vendor-vpn-killswitch.sh >/dev/null 2>&1")
		sys.call("/usr/bin/privacy-killswitch-watchdog.sh >/dev/null 2>&1")
		sys.call("/etc/init.d/firewall reload >/dev/null 2>&1")
		luci.http.redirect(disp.build_url("admin/services/glinet_privacy/killswitch"))
		return
	end

	local en = uci:get("privacy", "main", "enabled") or "1"
	local badge_label = translate("Watchdog disabled")
	local badge_class = "default"
	local badge_hint = translate("Killswitch rules are flushed when watchdog is off.")
	if en == "1" then
		if sh_ok("iptables -L FORWARD -n 2>/dev/null | grep -q privacy-killswitch-drop") then
			badge_label = translate("Blocking traffic")
			badge_class = "warning"
			badge_hint =
				translate("FORWARD DROP is active — VPN or Tor health checks failed from the router’s view.")
		else
			badge_label = translate("Watchdog active")
			badge_class = "success"
			badge_hint = translate("No emergency DROP — path looks healthy.")
		end
	end

	local net = require("luci.glinet_privacy.net_probe").snapshot()

	luci.template.render("glinet_privacy/killswitch", {
		badge_label = badge_label,
		badge_class = badge_class,
		badge_hint = badge_hint,
		net = net,
		form = {
			enabled = en,
			wg_if = uci:get("privacy", "main", "wg_if") or "wg0",
			require_wg = uci:get("privacy", "main", "require_wg") or "1",
			require_tor = uci:get("privacy", "main", "require_tor") or "1",
			lan_dev = uci:get("privacy", "main", "lan_dev") or "",
			wan_dev = uci:get("privacy", "main", "wan_dev") or "",
			vendor_gl_vpn_killswitch = uci:get("privacy", "main", "vendor_gl_vpn_killswitch") or "leave",
		},
	})
end

function action_imei()
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()
	local disp = require "luci.dispatcher"
	local sys = require "luci.sys"
	local detect = require "luci.glinet_privacy.imei_detect"

	local function yn(name)
		local v = http.formvalue(name)
		if type(v) == "table" then
			v = v[#v]
		end
		return v == "1" and "1" or "0"
	end

	local function str1(name)
		local v = http.formvalue(name)
		if type(v) == "table" then
			v = v[#v]
		end
		if type(v) ~= "string" then
			return ""
		end
		return v:gsub("^%s+", ""):gsub("%s+$", "")
	end

	if http.formvalue("submit") == "1" then
		uci:set("rotate_imei", "main", "enabled", yn("enabled"))
		uci:set("rotate_imei", "main", "cron_enabled", yn("cron_enabled"))
		local hrs = tonumber(http.formvalue("cron_interval_hours") or 6) or 6
		if hrs < 1 then
			hrs = 1
		end
		if hrs > 24 then
			hrs = 24
		end
		uci:set("rotate_imei", "main", "cron_interval_hours", tostring(hrs))
		uci:set("rotate_imei", "main", "cron_suppress_legal_log", yn("cron_suppress_legal_log"))
		local tac = str1("imei_tac"):gsub("%D", "")
		if #tac > 8 then
			tac = tac:sub(1, 8)
		end
		uci:set("rotate_imei", "main", "imei_tac", tac)
		uci:set("rotate_imei", "main", "modem_tty", str1("modem_tty"))
		uci:set("rotate_imei", "main", "wwan_if", str1("wwan_if"))
		uci:commit("rotate_imei")
		sys.call("/etc/init.d/rotate_imei enable 2>/dev/null")
		sys.call("/usr/libexec/glinet-privacy/apply-rotate-imei-cron.sh 2>/dev/null || true")
		luci.http.redirect(disp.build_url("admin/services/glinet_privacy/imei"))
		return
	end

	local preview = detect.get_preview()
	local saved_m = uci:get("rotate_imei", "main", "modem_tty") or ""
	local modem_opts = {}
	local seen_m = {}
	for _, d in ipairs(preview.tty_scan) do
		table.insert(modem_opts, d)
		seen_m[d] = true
	end
	if saved_m ~= "" and not seen_m[saved_m] then
		table.insert(modem_opts, saved_m)
	end
	local saved_w = uci:get("rotate_imei", "main", "wwan_if") or ""
	local wwan_opts = {}
	local seen_w = {}
	for _, n in ipairs(preview.iface_list) do
		table.insert(wwan_opts, n)
		seen_w[n] = true
	end
	if saved_w ~= "" and not seen_w[saved_w] then
		table.insert(wwan_opts, saved_w)
	end

	local slug = preview.slug
	local profile_blurb = ""
	if slug == "puli_xe300" then
		profile_blurb = translate("Cellular (Puli) — IMEI rotation applies when modem is present.")
	elseif slug == "slate_ax1800" or slug == "gl_ax1800" or slug == "generic" then
		profile_blurb =
			translate("Travel router profile — no built-in modem; leave rotation off unless you use USB cellular.")
	end

	luci.template.render("glinet_privacy/imei", {
		preview = preview,
		profile_blurb = profile_blurb,
		modem_opts = modem_opts,
		wwan_opts = wwan_opts,
		form = {
			enabled = uci:get("rotate_imei", "main", "enabled") or "0",
			cron_enabled = uci:get("rotate_imei", "main", "cron_enabled") or "0",
			cron_interval_hours = uci:get("rotate_imei", "main", "cron_interval_hours") or "6",
			cron_suppress_legal_log = uci:get("rotate_imei", "main", "cron_suppress_legal_log") or "0",
			imei_tac = uci:get("rotate_imei", "main", "imei_tac") or "",
			modem_sel = saved_m,
			wwan_sel = saved_w,
			preferred_modem = preview.preferred_modem or "",
			preferred_wwan = preview.preferred_wwan or "",
		},
	})
end

function action_tor_dns()
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()
	local disp = require "luci.dispatcher"
	local sys = require "luci.sys"

	local function yn(name)
		local v = http.formvalue(name)
		if type(v) == "table" then
			v = v[#v]
		end
		return v == "1" and "1" or "0"
	end

	local function str1(name)
		local v = http.formvalue(name)
		if type(v) == "table" then
			v = v[#v]
		end
		if type(v) ~= "string" then
			return ""
		end
		return v:gsub("^%s+", ""):gsub("%s+$", "")
	end

	if http.formvalue("submit") == "1" then
		uci:set("glinet_privacy", "hw", "auto_wan", yn("auto_wan"))
		uci:set("glinet_privacy", "tor", "tor_transparent", yn("tor_transparent"))
		uci:set("glinet_privacy", "tor", "lan_cidr", str1("lan_cidr"))
		uci:set("glinet_privacy", "tor", "router_lan_ip", str1("router_lan_ip"))
		uci:set("glinet_privacy", "tor", "lan_dev", str1("lan_dev"))
		local ttp = str1("tor_trans_port")
		if ttp == "" then
			ttp = "9040"
		end
		local tdp = str1("tor_dns_port")
		if tdp == "" then
			tdp = "9053"
		end
		uci:set("glinet_privacy", "tor", "tor_trans_port", ttp)
		uci:set("glinet_privacy", "tor", "tor_dns_port", tdp)

		uci:set("glinet_privacy", "tel", "block_domains", yn("block_domains"))
		uci:set("glinet_privacy", "tel", "disable_vendor_cloud", yn("disable_vendor_cloud"))
		uci:set("glinet_privacy", "tel", "remove_cloud_packages", yn("remove_cloud_packages"))

		local pol = str1("dns_policy")
		if pol ~= "default" and pol ~= "tor_dnsmasq" then
			pol = "default"
		end
		uci:set("glinet_privacy", "dns", "dns_policy", pol)
		uci:set("glinet_privacy", "dns", "redirect_tcp_dns", yn("redirect_tcp_dns"))
		uci:set("glinet_privacy", "dns", "block_lan_dot", yn("block_lan_dot"))

		uci:commit("glinet_privacy")
		sys.call("/usr/libexec/glinet-privacy/apply-dns-policy.sh >/dev/null 2>&1")
		sys.call("/etc/init.d/firewall reload >/dev/null 2>&1")
		sys.call("/usr/libexec/glinet-privacy/apply-telemetry.sh >/dev/null 2>&1")
		sys.call("/etc/init.d/dnsmasq restart >/dev/null 2>&1")
		luci.http.redirect(disp.build_url("admin/services/glinet_privacy/plugins"))
		return
	end

	local tt = uci:get("glinet_privacy", "tor", "tor_transparent") or "0"
	local tor_badge_class, tor_badge_label, tor_hint
	if tt ~= "1" then
		tor_badge_class = "default"
		tor_badge_label = translate("Tor NAT off")
		tor_hint = translate("Transparent redirects are disabled in UCI.")
	else
		if sh_ok("iptables -t nat -L PREROUTING -n 2>/dev/null | grep -q REDIRECT") then
			tor_badge_class = "success"
			tor_badge_label = translate("NAT redirects present")
			tor_hint = translate("PREROUTING REDIRECT rules present (Tor TransPort path).")
		else
			tor_badge_class = "warning"
			tor_badge_label = translate("Tor NAT — check firewall")
			tor_hint = translate("UCI is on but no REDIRECT seen yet — save & apply or reload firewall.")
		end
	end

	local dns_pol = uci:get("glinet_privacy", "dns", "dns_policy") or "default"
	local dns_badge_class = "default"
	local dns_badge_label = translate("Router DNS: default")
	if dns_pol == "tor_dnsmasq" then
		dns_badge_class = "info"
		dns_badge_label = translate("Router DNS → Tor")
	end

	local blk = uci:get("glinet_privacy", "tel", "block_domains") or "0"
	local tel_badge_class = "default"
	local tel_badge_label = translate("Telemetry blocklist off")
	if blk == "1" then
		tel_badge_class = "success"
		tel_badge_label = translate("Telemetry blocklist on")
	end

	local net = require("luci.glinet_privacy.net_probe").snapshot()
	local function tor_field(section, opt, fallback, runtime)
		local v = uci:get("glinet_privacy", section, opt)
		if v and v ~= "" then
			return v
		end
		if runtime and runtime ~= "" then
			return runtime
		end
		return fallback
	end

	luci.template.render("glinet_privacy/tor_dns", {
		verify_url = disp.build_url("admin/services/glinet_privacy/verify"),
		tor_badge_class = tor_badge_class,
		tor_badge_label = tor_badge_label,
		tor_hint = tor_hint,
		dns_badge_class = dns_badge_class,
		dns_badge_label = dns_badge_label,
		tel_badge_class = tel_badge_class,
		tel_badge_label = tel_badge_label,
		profile_slug = uci:get("glinet_privacy", "hw", "slug") or "",
		profile_board = uci:get("glinet_privacy", "hw", "board_hint") or "",
		net = net,
		form = {
			auto_wan = uci:get("glinet_privacy", "hw", "auto_wan") or "1",
			tor_transparent = uci:get("glinet_privacy", "tor", "tor_transparent") or "0",
			lan_cidr = tor_field("tor", "lan_cidr", "192.168.8.0/24", net.lan_cidr_guess),
			router_lan_ip = tor_field("tor", "router_lan_ip", "192.168.8.1", net.router_lan_ip),
			lan_dev = uci:get("glinet_privacy", "tor", "lan_dev") or "",
			tor_trans_port = uci:get("glinet_privacy", "tor", "tor_trans_port") or "9040",
			tor_dns_port = uci:get("glinet_privacy", "tor", "tor_dns_port") or "9053",
			block_domains = uci:get("glinet_privacy", "tel", "block_domains") or "0",
			disable_vendor_cloud = uci:get("glinet_privacy", "tel", "disable_vendor_cloud") or "0",
			remove_cloud_packages = uci:get("glinet_privacy", "tel", "remove_cloud_packages") or "0",
			dns_policy = dns_pol,
			redirect_tcp_dns = uci:get("glinet_privacy", "dns", "redirect_tcp_dns") or "1",
			block_lan_dot = uci:get("glinet_privacy", "dns", "block_lan_dot") or "0",
		},
	})
end

function action_verify()
	local net = require("luci.glinet_privacy.net_probe").snapshot()
	luci.template.render("glinet_privacy/verify", {
		net = net,
	})
end
