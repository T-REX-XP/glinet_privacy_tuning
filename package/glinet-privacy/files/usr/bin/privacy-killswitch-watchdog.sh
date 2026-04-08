#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# privacy-killswitch-watchdog.sh — Block LAN→WAN forward when WireGuard and/or Tor are unhealthy.
# Uses iptables (xtables-nft on OpenWrt). Requires comment match (kmod-ipt-comment).

set -eu

load_uci() {
	if [ -f /etc/config/privacy ]; then
		ENABLED="$(uci -q get privacy.main.enabled 2>/dev/null || echo 1)"
		WG_IF="$(uci -q get privacy.main.wg_if 2>/dev/null || echo wg0)"
		REQUIRE_TOR="$(uci -q get privacy.main.require_tor 2>/dev/null || echo 1)"
		REQUIRE_WG="$(uci -q get privacy.main.require_wg 2>/dev/null || echo 1)"
		LAN_DEV="$(uci -q get privacy.main.lan_dev 2>/dev/null || echo "")"
		WAN_DEV="$(uci -q get privacy.main.wan_dev 2>/dev/null || echo "")"
	else
		ENABLED="${PRIVACY_KS_ENABLED:-1}"
		WG_IF="${WG_IF:-wg0}"
		REQUIRE_TOR="${REQUIRE_TOR:-1}"
		REQUIRE_WG="${REQUIRE_WG:-1}"
		LAN_DEV="${LAN_DEV:-}"
		WAN_DEV="${WAN_DEV:-}"
	fi
}

detect_lan() {
	if [ -n "$LAN_DEV" ]; then
		printf '%s' "$LAN_DEV"
		return
	fi
	uci -q get network.lan.device 2>/dev/null || echo "br-lan"
}

detect_wan() {
	if [ -n "$WAN_DEV" ]; then
		printf '%s' "$WAN_DEV"
		return
	fi
	for _n in wan wwan modem; do
		_d="$(uci -q get "network.${_n}.device" 2>/dev/null || true)"
		if [ -n "$_d" ]; then
			printf '%s' "$_d"
			return
		fi
	done
	# Fallback: first non-loopback default route interface
	ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
}

KS_COMMENT="privacy-killswitch-drop"

rule_exists() {
	iptables -C FORWARD -i "$1" -o "$2" -m comment --comment "$KS_COMMENT" -j DROP 2>/dev/null
}

add_rule() {
	rule_exists "$1" "$2" && return 0
	iptables -I FORWARD 1 -i "$1" -o "$2" -m comment --comment "$KS_COMMENT" -j DROP
}

del_rule() {
	while iptables -C FORWARD -i "$1" -o "$2" -m comment --comment "$KS_COMMENT" -j DROP 2>/dev/null; do
		iptables -D FORWARD -i "$1" -o "$2" -m comment --comment "$KS_COMMENT" -j DROP
	done
}

wg_up() {
	[ "$REQUIRE_WG" = "0" ] && return 0
	ip link show "$WG_IF" 2>/dev/null | grep -q "state UP"
}

tor_up() {
	[ "$REQUIRE_TOR" = "0" ] && return 0
	pidof tor >/dev/null 2>&1
}

healthy() {
	wg_up && tor_up
}

run_flush() {
	load_uci
	_lan="$(detect_lan)"
	_wan="$(detect_wan)"
	[ -n "$_wan" ] || return 0
	del_rule "$_lan" "$_wan" 2>/dev/null || true
}

main() {
	case "${1:-}" in
		--flush) run_flush; exit 0 ;;
	esac

	load_uci
	case "$ENABLED" in
		0|false|off|no) del_rule "$(detect_lan)" "$(detect_wan)" 2>/dev/null || true; exit 0 ;;
	esac

	_lan="$(detect_lan)"
	_wan="$(detect_wan)"
	if [ -z "$_wan" ]; then
		logger -t privacy-ks "WAN interface unknown — set privacy.main.wan_dev or network.wan/wwan.device"
		exit 1
	fi

	if healthy; then
		del_rule "$_lan" "$_wan"
		logger -t privacy-ks "healthy: wg=${WG_IF} tor=ok — removed killswitch DROP ($_lan -> $_wan)"
	else
		add_rule "$_lan" "$_wan"
		_reason=""
		wg_up || _reason="${_reason} wg_down"
		tor_up || _reason="${_reason} tor_down"
		logger -t privacy-ks "UNHEALTHY:${_reason} — FORWARD DROP $_lan -> $_wan"
	fi
}

main "$@"
