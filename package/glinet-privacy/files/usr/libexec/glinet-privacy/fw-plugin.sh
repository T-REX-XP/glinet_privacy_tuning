#!/bin/sh
# glinet-privacy firewall plugin — single OpenWrt firewall include entry point.
# Registered as firewall.glinet_privacy.path (see postinst / uci-defaults).

set -eu

TOR_EN="$(uci -q get glinet_privacy.tor.tor_transparent 2>/dev/null || echo 0)"
case "$TOR_EN" in
	1|true|yes|on)
		/etc/firewall.privacy-tor.sh
		;;
esac

exit 0
