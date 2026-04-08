#!/bin/sh
# glinet-privacy firewall plugin — OpenWrt firewall include entry point (fw3/fw4).
# Registered as firewall.glinet_privacy.path; also invoked from /etc/firewall.user
# (glinet-privacy-fw-plugin) for GL.iNet images where UCI include may be reset on upgrade.

set -eu

TOR_EN="$(uci -q get glinet_privacy.tor.tor_transparent 2>/dev/null || echo 0)"
case "$TOR_EN" in
	1|true|yes|on)
		/etc/firewall.privacy-tor.sh
		;;
esac

exit 0
