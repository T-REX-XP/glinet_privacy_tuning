#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# apply-vendor-vpn-killswitch.sh — Best-effort sync of GL.iNet stock "Block Non-VPN Traffic" (VPN kill switch)
# via UCI glvpn when present (vendor firmware). See docs/devices.md — coexistence with privacy-killswitch-watchdog.

set -eu

MODE="$(uci -q get privacy.main.vendor_gl_vpn_killswitch 2>/dev/null || echo leave)"
case "$MODE" in
	on|1|true|yes) WANT=1 ;;
	off|0|false|no) WANT=0 ;;
	leave|default|"") exit 0 ;;
	*) exit 0 ;;
esac

if [ ! -f /etc/config/glvpn ]; then
	logger -t glinet-vendor-ks "no /etc/config/glvpn — skip (not GL.iNet vendor VPN stack or glvpn not installed)" 2>/dev/null || true
	exit 0
fi

if ! uci -q get glvpn.general >/dev/null 2>&1; then
	logger -t glinet-vendor-ks "glvpn.general missing — skip (firmware may use dashboard-only kill switch on v4.8+)" 2>/dev/null || true
	exit 0
fi

uci set "glvpn.general.block_non_vpn=$WANT"
uci commit glvpn
if [ -x /etc/init.d/glvpn ]; then
	/etc/init.d/glvpn restart >/dev/null 2>&1 || true
fi
logger -t glinet-vendor-ks "set glvpn.general.block_non_vpn=$WANT (privacy.main.vendor_gl_vpn_killswitch=$MODE)" 2>/dev/null || true

exit 0
