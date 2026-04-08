--[[
LuCI: GL.iNet Privacy — Services menu
]]

module("luci.controller.glinet_privacy", package.seeall)

require "luci.glinet_privacy.i18n"

function index()
	entry({"admin", "services", "glinet_privacy"},
		alias("admin", "services", "glinet_privacy", "overview"),
		_("GL.iNet Privacy"), 60)

	entry({"admin", "services", "glinet_privacy", "overview"},
		call("action_overview"), _("Overview"), 1)
	entry({"admin", "services", "glinet_privacy", "killswitch"},
		cbi("glinet_privacy/killswitch"), _("Kill switch"), 2)
	entry({"admin", "services", "glinet_privacy", "imei"},
		cbi("glinet_privacy/imei"), _("IMEI rotation"), 3)
	entry({"admin", "services", "glinet_privacy", "plugins"},
		cbi("glinet_privacy/plugins"), _("Tor, DNS & telemetry"), 4)
	entry({"admin", "services", "glinet_privacy", "wireguard"},
		template("glinet_privacy/wireguard"), _("WireGuard / Mullvad"), 5)
end

local function sh_ok(cmd)
	return luci.sys.call(cmd .. " >/dev/null 2>&1") == 0
end

function build_status()
	local uci = require "luci.model.uci".cursor()
	local items = {}
	local ok_c, problem_c, skip_c = 0, 0, 0

	local function add(id, label, detail, state)
		table.insert(items, { id = id, label = label, detail = detail or "", state = state })
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
		add("fw_inc", translate("Firewall plugin registered"), "", "ok")
	else
		add("fw_inc", translate("Firewall plugin registered"), translate("Missing UCI firewall.glinet_privacy"), "bad")
	end

	local wg_if = uci:get("privacy", "main", "wg_if") or "wg0"
	local req_wg = uci:get("privacy", "main", "require_wg") or "1"
	if req_wg == "0" then
		add("wg", translatef("WireGuard (%s)", wg_if), translate("Not required"), "skip")
	elseif sh_ok("ip link show " .. wg_if .. " 2>/dev/null | grep -q 'state UP'") then
		add("wg", translatef("WireGuard (%s)", wg_if), translate("Interface up"), "ok")
	else
		add("wg", translatef("WireGuard (%s)", wg_if), translate("Down or missing"), "bad")
	end

	local req_tor = uci:get("privacy", "main", "require_tor") or "1"
	if req_tor == "0" then
		add("tor_proc", translate("Tor daemon"), translate("Not required by kill switch"), "skip")
	elseif sh_ok("pidof tor") then
		add("tor_proc", translate("Tor daemon"), translate("Running"), "ok")
	else
		add("tor_proc", translate("Tor daemon"), translate("Not running"), "bad")
	end

	local tt = uci:get("glinet_privacy", "tor", "tor_transparent") or "0"
	if tt == "1" then
		if sh_ok("iptables -t nat -L PREROUTING -n 2>/dev/null | grep -q REDIRECT") then
			add("tor_nat", translate("Tor transparent NAT"), translate("REDIRECT rules present"), "ok")
		else
			add("tor_nat", translate("Tor transparent NAT"), translate("UCI enabled; no REDIRECT in NAT table"), "warn")
		end
	else
		add("tor_nat", translate("Tor transparent NAT"), translate("Disabled"), "skip")
	end

	local ks_en = uci:get("privacy", "main", "enabled") or "1"
	if ks_en == "1" then
		if sh_ok("iptables -L FORWARD -n 2>/dev/null | grep -q privacy-killswitch-drop") then
			add("ks", translate("Kill switch"), translate("Emergency DROP active (VPN/Tor unhealthy?)"), "warn")
		else
			add("ks", translate("Kill switch"), translate("Watchdog active; no DROP (healthy)"), "ok")
		end
	else
		add("ks", translate("Kill switch"), translate("Disabled"), "skip")
	end

	if sh_ok("grep -q privacy-killswitch-watchdog /etc/crontabs/root 2>/dev/null") then
		add("cron", translate("Cron watchdog"), translate("Scheduled"), "ok")
	else
		add("cron", translate("Cron watchdog"), translate("No crontab line"), "warn")
	end

	local blk = uci:get("glinet_privacy", "tel", "block_domains") or "0"
	if blk == "1" then
		add("tel", translate("Telemetry DNS block"), translate("Enabled"), "ok")
	else
		add("tel", translate("Telemetry DNS block"), translate("Off"), "skip")
	end

	if sh_ok("opkg list-installed 2>/dev/null | grep -q '^tor '") or sh_ok("command -v tor") then
		add("pkg_tor", translate("tor package / binary"), translate("Present"), "ok")
	else
		add("pkg_tor", translate("tor package / binary"), translate("Missing"), "warn")
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
		uci:foreach("rotate_imei", "rotate_imei", function(s)
			uci:set("rotate_imei", s[".name"], "enabled", yn("f_rotate_imei"))
			ri_changed = true
		end)

		uci:commit("privacy")
		uci:commit("glinet_privacy")
		if ri_changed then
			uci:commit("rotate_imei")
		end

		sys.call("/usr/bin/privacy-killswitch-watchdog.sh >/dev/null 2>&1")
		sys.call("/usr/libexec/glinet-privacy/apply-telemetry.sh >/dev/null 2>&1")
		sys.call("/etc/init.d/firewall reload >/dev/null 2>&1")
		sys.call("/etc/init.d/dnsmasq restart >/dev/null 2>&1")

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

	luci.template.render("glinet_privacy/overview", {
		status = st,
		form = form
	})
end
