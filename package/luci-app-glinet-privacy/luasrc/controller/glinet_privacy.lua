--[[
LuCI: GL.iNet Privacy — Services menu
]]

module("luci.controller.glinet_privacy", package.seeall)

function index()
	entry({"admin", "services", "glinet_privacy"},
		alias("admin", "services", "glinet_privacy", "killswitch"),
		_("GL.iNet Privacy"), 60)

	entry({"admin", "services", "glinet_privacy", "killswitch"},
		cbi("glinet_privacy/killswitch"), _("Kill switch"), 1)
	entry({"admin", "services", "glinet_privacy", "imei"},
		cbi("glinet_privacy/imei"), _("IMEI rotation"), 2)
	entry({"admin", "services", "glinet_privacy", "plugins"},
		cbi("glinet_privacy/plugins"), _("Tor & telemetry"), 3)
	entry({"admin", "services", "glinet_privacy", "wireguard"},
		template("glinet_privacy/wireguard"), _("WireGuard / Mullvad"), 4)
end
