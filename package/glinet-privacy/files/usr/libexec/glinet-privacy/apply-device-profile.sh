#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# Detect GL.iNet / OpenWrt board and set sensible privacy.main.wan_dev + glinet_privacy.hw.slug.
# GL-XE300 (Puli): cellular — default wwan0 when empty.
# GL-AXT1800 (Slate AX), GL-AX1800 (Flint), etc.: Ethernet / travel — clear mistaken wwan0.

set -eu

read_board_haystack() {
	_h=""
	if [ -r /tmp/sysinfo/board_name ]; then
		_h="${_h} $(cat /tmp/sysinfo/board_name)"
	fi
	if [ -r /etc/board.json ]; then
		if command -v jsonfilter >/dev/null 2>&1; then
			_h="${_h} $(jsonfilter -q -i /etc/board.json -e '@.model.id' 2>/dev/null || true)"
			_h="${_h} $(jsonfilter -q -i /etc/board.json -e '@.model.name' 2>/dev/null || true)"
		fi
		_h="${_h} $(sed -n 's/.*"board_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /etc/board.json 2>/dev/null | head -1)"
	fi
	if command -v ubus >/dev/null 2>&1; then
		_h="${_h} $(ubus call system board 2>/dev/null | sed -n 's/.*"board_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
	fi
	# shellcheck disable=SC2086
	printf '%s' "$_h" | tr '[:upper:]' '[:lower:]'
}

detect_slug() {
	_hay="$(read_board_haystack)"
	_slug="generic"

	case "$_hay" in
		*xe300*|*gl-xe300*)
			_slug="puli_xe300"
			;;
		*axt1800*|*gl-axt1800*)
			_slug="slate_ax1800"
			;;
		*gl-ax1800*|*flint*)
			_slug="gl_ax1800"
			;;
		*)
			_slug="generic"
			;;
	esac

	printf '%s' "$_slug"
}

apply_wan_defaults() {
	_slug="$1"
	_auto="$(uci -q get glinet_privacy.hw.auto_wan 2>/dev/null || echo 1)"
	case "$_auto" in
		0|false|off|no) return 0 ;;
	esac

	case "$_slug" in
		puli_xe300)
			_cur="$(uci -q get privacy.main.wan_dev 2>/dev/null || echo "")"
			if [ -z "$_cur" ]; then
				uci set privacy.main.wan_dev='wwan0'
			fi
			;;
		slate_ax1800|gl_ax1800)
			_cur="$(uci -q get privacy.main.wan_dev 2>/dev/null || echo "")"
			if [ "$_cur" = "wwan0" ]; then
				uci set privacy.main.wan_dev=''
			fi
			;;
		generic)
			;;
	esac
}

main() {
	[ -f /etc/config/glinet_privacy ] || return 0
	[ -f /etc/config/privacy ] || return 0

	if ! uci -q show glinet_privacy.hw >/dev/null 2>&1; then
		uci set glinet_privacy.hw=device
		uci set glinet_privacy.hw.slug='auto'
		uci set glinet_privacy.hw.auto_wan='1'
		uci set glinet_privacy.hw.board_hint=''
	fi

	_slug="$(detect_slug)"
	_board_raw="$(read_board_haystack | tr -s ' ' | head -c 200)"

	uci set glinet_privacy.hw.slug="$_slug"
	uci set glinet_privacy.hw.board_hint="$_board_raw"
	uci commit glinet_privacy

	apply_wan_defaults "$_slug"

	uci commit privacy 2>/dev/null || true
}

main "$@"
