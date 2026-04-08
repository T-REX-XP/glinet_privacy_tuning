#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# Sync /etc/crontabs/root IMEI rotation line from UCI rotate_imei.main (cron_enabled, cron_interval_hours, cron_suppress_legal_log).
# Legal: see docs/devices.md (IMEI section).

set -eu

CR="/etc/crontabs/root"
ROT="/usr/bin/rotate_imei.sh"

[ -f /etc/config/rotate_imei ] || exit 0

ENABLED="$(uci -q get rotate_imei.main.cron_enabled 2>/dev/null || true)"
if [ -z "$ENABLED" ]; then
	if [ -f "$CR" ] && grep -qF "$ROT" "$CR" 2>/dev/null; then
		ENABLED=1
	else
		ENABLED=0
	fi
fi

case "$ENABLED" in 1|true|yes|on) _en=1 ;; *) _en=0 ;; esac

INTERVAL="$(uci -q get rotate_imei.main.cron_interval_hours 2>/dev/null || echo 6)"
case "$INTERVAL" in ''|*[!0-9]*) INTERVAL=6 ;; esac
if [ "$INTERVAL" -lt 1 ]; then INTERVAL=1; fi
if [ "$INTERVAL" -gt 24 ]; then INTERVAL=24; fi

case "$INTERVAL" in
	1) SCHED="0 * * * *" ;;
	24) SCHED="0 0 * * *" ;;
	*) SCHED="0 */${INTERVAL} * * *" ;;
esac

SUPPRESS="$(uci -q get rotate_imei.main.cron_suppress_legal_log 2>/dev/null || echo 0)"
case "$SUPPRESS" in 1|true|yes|on)
	CMD="ROTATE_IMEI_SUPPRESS_LEGAL_LOG=1 $ROT"
	;;
*)
	CMD="$ROT"
	;;
esac

LINE="$SCHED $CMD"

if [ -f "$CR" ]; then
	_tmp="${CR}.tmp.$$"
	grep -vF "$ROT" "$CR" > "$_tmp" || true
	mv -f "$_tmp" "$CR"
fi

if [ "$_en" -eq 1 ]; then
	mkdir -p "$(dirname "$CR")"
	[ -f "$CR" ] || touch "$CR"
	printf '%s\n' "$LINE" >> "$CR"
fi

if [ -x /etc/init.d/cron ]; then
	/etc/init.d/cron restart 2>/dev/null || true
fi

exit 0
