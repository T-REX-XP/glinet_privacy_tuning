#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# Apply dnsmasq GL.iNet blocklist from /etc/glinet-privacy/glinet-block.conf
# When "disable vendor cloud" is on, also install the same DNS black-holes (reference: goodcloud.xyz, gldns.com).

set -eu

BLOCK="$(uci -q get glinet_privacy.tel.block_domains 2>/dev/null || echo 0)"
DIS="$(uci -q get glinet_privacy.tel.disable_vendor_cloud 2>/dev/null || echo 0)"
SRC="/etc/glinet-privacy/glinet-block.conf"
DST="/etc/dnsmasq.d/glinet-block.conf"

# Full blocklist OR vendor-cloud disable: DNS-level blocking via dnsmasq.d (not /etc/dnsmasq.conf append).
case "$BLOCK" in 1|true|yes|on) _want=1 ;; *) _want=0 ;; esac
case "$DIS" in 1|true|yes|on) _want=1 ;; *) ;; esac

case "$_want" in
	1)
		if [ -f "$SRC" ]; then
			mkdir -p "$(dirname "$DST")"
			ln -sf "$SRC" "$DST" 2>/dev/null || cp -f "$SRC" "$DST"
		fi
		;;
	*)
		rm -f "$DST"
		;;
esac

case "$DIS" in
	1|true|yes|on)
		/usr/bin/disable-glinet-telemetry.sh
		;;
esac

exit 0
