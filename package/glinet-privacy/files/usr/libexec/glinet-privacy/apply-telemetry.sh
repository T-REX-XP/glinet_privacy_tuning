#!/bin/sh
# Apply dnsmasq GL.iNet blocklist from /etc/glinet-privacy/glinet-block.conf

set -eu

BLOCK="$(uci -q get glinet_privacy.tel.block_domains 2>/dev/null || echo 0)"
SRC="/etc/glinet-privacy/glinet-block.conf"
DST="/etc/dnsmasq.d/glinet-block.conf"

case "$BLOCK" in
	1|true|yes|on)
		if [ -f "$SRC" ]; then
			ln -sf "$SRC" "$DST" 2>/dev/null || cp -f "$SRC" "$DST"
		fi
		;;
	*)
		rm -f "$DST"
		;;
esac

DIS="$(uci -q get glinet_privacy.tel.disable_vendor_cloud 2>/dev/null || echo 0)"
case "$DIS" in
	1|true|yes|on)
		/usr/bin/disable-glinet-telemetry.sh
		;;
esac

exit 0
