#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# JSON helpers for LuCI JS views (no Lua). Subcommands:
#   overview | net_probe | privacy_log | imei_preview | vendor_ubus | verify_ip
# Requires: uci, jshn (libubox), standard busybox/coreutils.

set -eu

JSHN_OK=0
if [ -f /usr/share/libubox/jshn.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/libubox/jshn.sh && JSHN_OK=1
fi

die_json() {
	printf '%s\n' "{\"error\":\"$1\"}"
	exit 1
}

uci_get() {
	uci -q get "$1" 2>/dev/null || true
}

sh_ok() {
	_sh="$1"
	eval "$_sh" >/dev/null 2>&1
}

json_verify_ip() {
	_body=""
	for _cmd in \
		"uclient-fetch -q -O- 'https://api.ipify.org?format=json' 2>/dev/null" \
		"wget -qO- 'https://api.ipify.org?format=json' 2>/dev/null" \
		"curl -fsS -m 12 'https://api.ipify.org?format=json' 2>/dev/null"
	do
		_body="$(eval "$_cmd")" || _body=""
		if [ -n "$_body" ] && echo "$_body" | grep -q '"ip"'; then
			printf '%s\n' "$_body"
			return 0
		fi
	done
	die_json "router_fetch_failed"
}

# --- privacy_log (matches privacy_log_excerpt.lua intent) ---
json_privacy_log() {
	_tmp="/tmp/glp-log.$$"
	logread 2>/dev/null | tail -320 2>/dev/null | grep -E 'privacy-ks|glinet-|rotate_imei' >"$_tmp" || true
	if [ ! -s "$_tmp" ]; then
		rm -f "$_tmp"
		if [ "$JSHN_OK" -eq 1 ]; then
			json_init
			json_add_boolean empty 1
			json_add_array lines
			json_close_array
			json_add_string last_line ""
			json_add_string last_line_full ""
			json_add_string tooltip_title ""
			json_dump
		else
			printf '%s\n' '{"empty":true,"lines":[],"last_line":"","last_line_full":"","tooltip_title":""}'
		fi
		return 0
	fi
	_tail="$(tail -14 "$_tmp")"
	_ll="$(tail -1 "$_tmp")"
	rm -f "$_tmp"
	if [ "$JSHN_OK" -eq 1 ]; then
		json_init
		json_add_boolean empty 0
		json_add_array lines
		while IFS= read -r _ln; do
			json_add_string "" "$_ln"
		done <<EOF
$_tail
EOF
		json_close_array
		json_add_string last_line "$(echo "$_ll" | cut -c1-96)"
		json_add_string last_line_full "$_ll"
		json_add_string tooltip_title "$(echo "$_tail" | tail -8 | tr '\n' ' ' | cut -c1-1600)"
		json_dump
	else
		die_json "no_jshn"
	fi
}

# --- net_probe snapshot (subset; JS consumes same keys as former Lua) ---
json_net_probe() {
	_lan_uci="br-lan"
	_d="$(uci_get network.lan.device)"
	[ -n "$_d" ] && _lan_uci="$_d"
	_pl="$(uci_get privacy.main.lan_dev)"
	_lan_eff="$_lan_uci"
	[ -n "$_pl" ] && _lan_eff="$_pl"

	_pw="$(uci_get privacy.main.wan_dev)"
	_wan=""
	_src=""
	if [ -n "$_pw" ]; then
		_wan="$_pw"
		_src="privacy.uci"
	else
		for _n in wan wwan modem; do
			if uci -q get "network.$_n" >/dev/null 2>&1; then
				_dd="$(uci_get "network.${_n}.device")"
				if [ -n "$_dd" ]; then
					_wan="$_dd"
					_src="network.$_n"
					break
				fi
			fi
		done
	fi
	if [ -z "$_wan" ]; then
		_wan="$(ip -4 route show default 2>/dev/null | head -1 | sed -n 's/.* dev \([^ ]*\).*/\1/p')"
		_src="route.default"
	fi

	_rip=""
	_cidr=""
	if [ -n "$_lan_eff" ]; then
		_cidr="$(ip -o -f inet route show dev "$_lan_eff" scope link 2>/dev/null | head -1 | awk '{print $1}')"
		_rip="$(ip -o -f inet addr show dev "$_lan_eff" 2>/dev/null | head -1 | awk '{print $4}' | cut -d/ -f1)"
	fi
	[ -z "$_rip" ] && _rip="$(uci_get network.lan.ipaddr)"

	_wd_lan="$_lan_eff"
	_wd_wan="$_wan"
	_slug="$(uci_get glinet_privacy.hw.slug)"

	if [ "$JSHN_OK" -eq 1 ]; then
		json_init
		json_add_string lan_device_uci "$_lan_uci"
		json_add_string lan_device_privacy_saved "$(uci_get privacy.main.lan_dev)"
		json_add_string lan_device_effective "$_lan_eff"
		json_add_string wan_device_privacy_saved "$(uci_get privacy.main.wan_dev)"
		json_add_string wan_device_effective "$_wan"
		json_add_string wan_source "$_src"
		json_add_string router_lan_ip "${_rip:-}"
		json_add_string lan_ip_cidr ""
		json_add_string lan_cidr_guess "${_cidr:-}"
		json_add_array wireguard_ifaces
		for _if in $(ip -o link show type wireguard 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1); do
			[ -n "$_if" ] && json_add_string "" "$_if"
		done
		json_close_array
		if uci -q show glvpn >/dev/null 2>&1; then
			json_add_boolean glvpn_present 1
		else
			json_add_boolean glvpn_present 0
		fi
		json_add_string glvpn_block_non_vpn ""
		json_add_string watchdog_lan "$_wd_lan"
		json_add_string watchdog_wan "$_wd_wan"
		json_add_string watchdog_wan_source "$_src"
		if [ -n "$_wan" ]; then
			json_add_boolean watchdog_wan_known 1
		else
			json_add_boolean watchdog_wan_known 0
		fi
		json_add_boolean watchdog_differs_from_probe 0
		json_add_string slug "$_slug"
		json_dump
	else
		die_json "no_jshn"
	fi
}

# --- overview status (build_status parity, shell) ---
json_overview() {
	_ok=0
	_bad=0
	_skip=0
	json_init
	json_add_array items

	_slug="$(uci_get glinet_privacy.hw.slug)"
	[ -z "$_slug" ] && _slug="?"
	json_add_object
	json_add_string id profile
	json_add_string label "Device profile"
	json_add_string detail "$_slug"
	json_add_string state ok
	json_close_object
	_ok=$((_ok + 1))

	if uci -q get firewall.glinet_privacy >/dev/null 2>&1; then
		json_add_object
		json_add_string id fw_inc
		json_add_string label "Firewall plugin"
		json_add_string detail "Registered"
		json_add_string state ok
		json_close_object
		_ok=$((_ok + 1))
	else
		json_add_object
		json_add_string id fw_inc
		json_add_string label "Firewall plugin"
		json_add_string detail "Missing UCI firewall.glinet_privacy"
		json_add_string state bad
		json_close_object
		_bad=$((_bad + 1))
	fi

	_wg_raw="$(uci_get privacy.main.wg_if)"
	[ -z "$_wg_raw" ] && _wg_raw="wg0"
	_req_wg="$(uci_get privacy.main.require_wg)"
	[ -z "$_req_wg" ] && _req_wg="1"

	if echo "$_wg_raw" | grep -qE '^[a-zA-Z0-9._:-]{1,15}$'; then
		_wg_safe="$_wg_raw"
	else
		_wg_safe=""
	fi

	if [ -z "$_wg_safe" ] && [ -n "$_wg_raw" ]; then
		json_add_object
		json_add_string id wg
		json_add_string label "WireGuard"
		json_add_string detail "Invalid interface name in UCI"
		json_add_string state bad
		json_add_string toggle f_require_wg
		json_close_object
		_bad=$((_bad + 1))
	elif [ "$_req_wg" = "0" ]; then
		json_add_object
		json_add_string id wg
		json_add_string label "WireGuard"
		json_add_string detail "Not required"
		json_add_string state skip
		json_add_string toggle f_require_wg
		json_close_object
		_skip=$((_skip + 1))
	else
		_up=0
		if [ -n "$_wg_safe" ] && sh_ok "ip link show ${_wg_safe} 2>/dev/null | grep -q 'state UP'"; then
			_up=1
		fi
		_st="bad"
		_det="Down or missing"
		if [ "$_up" -eq 1 ]; then
			_st="ok"
			_det="Interface up"
		fi
		json_add_object
		json_add_string id wg
		json_add_string label "WireGuard (${_wg_raw})"
		json_add_string detail "$_det"
		json_add_string state "$_st"
		json_add_string toggle f_require_wg
		json_close_object
		if [ "$_st" = "ok" ]; then _ok=$((_ok + 1)); else _bad=$((_bad + 1)); fi
	fi

	_req_tor="$(uci_get privacy.main.require_tor)"
	[ -z "$_req_tor" ] && _req_tor="1"
	if [ "$_req_tor" = "0" ]; then
		json_add_object
		json_add_string id tor_proc
		json_add_string label "Tor daemon"
		json_add_string detail "Not required by kill switch"
		json_add_string state skip
		json_add_string toggle f_require_tor
		json_close_object
		_skip=$((_skip + 1))
	elif sh_ok "pidof tor"; then
		json_add_object
		json_add_string id tor_proc
		json_add_string label "Tor daemon"
		json_add_string detail "Running"
		json_add_string state ok
		json_add_string toggle f_require_tor
		json_close_object
		_ok=$((_ok + 1))
	else
		json_add_object
		json_add_string id tor_proc
		json_add_string label "Tor daemon"
		json_add_string detail "Not running"
		json_add_string state bad
		json_add_string toggle f_require_tor
		json_close_object
		_bad=$((_bad + 1))
	fi

	_tt="$(uci_get glinet_privacy.tor.tor_transparent)"
	[ -z "$_tt" ] && _tt="0"
	_tp="$(uci_get glinet_privacy.tor.tor_trans_port)"
	[ -z "$_tp" ] && _tp="9040"
	_dp="$(uci_get glinet_privacy.tor.tor_dns_port)"
	[ -z "$_dp" ] && _dp="9053"

	if [ "$_tt" = "1" ]; then
		_nat=0
		if [ -x /usr/libexec/glinet-privacy/tor-transparent-nat-active.sh ]; then
			/usr/libexec/glinet-privacy/tor-transparent-nat-active.sh "$_tp" "$_dp" >/dev/null 2>&1 && _nat=1 || true
		fi
		if [ "$_nat" -eq 1 ]; then
			json_add_object
			json_add_string id tor_nat
			json_add_string label "Tor transparent NAT"
			json_add_string detail "REDIRECT / nft redirect rules present"
			json_add_string state ok
			json_add_string toggle f_tor_transparent
			json_close_object
			_ok=$((_ok + 1))
		else
			json_add_object
			json_add_string id tor_nat
			json_add_string label "Tor transparent NAT"
			json_add_string detail "UCI enabled; no REDIRECT/redirect seen"
			json_add_string state warn
			json_add_string toggle f_tor_transparent
			json_close_object
		fi
	else
		json_add_object
		json_add_string id tor_nat
		json_add_string label "Tor transparent NAT"
		json_add_string detail "Disabled"
		json_add_string state skip
		json_add_string toggle f_tor_transparent
		json_close_object
		_skip=$((_skip + 1))
	fi

	_ks_en="$(uci_get privacy.main.enabled)"
	[ -z "$_ks_en" ] && _ks_en="1"
	if [ "$_ks_en" = "1" ]; then
		_drop=0
		if [ -x /usr/libexec/glinet-privacy/killswitch-drop-active.sh ]; then
			/usr/libexec/glinet-privacy/killswitch-drop-active.sh >/dev/null 2>&1 && _drop=1 || true
		fi
		if [ "$_drop" -eq 1 ]; then
			json_add_object
			json_add_string id ks
			json_add_string label "Kill switch"
			json_add_string detail "Emergency DROP active"
			json_add_string state warn
			json_add_string toggle f_privacy_enabled
			json_close_object
		else
			json_add_object
			json_add_string id ks
			json_add_string label "Kill switch"
			json_add_string detail "Watchdog active; no DROP"
			json_add_string state ok
			json_add_string toggle f_privacy_enabled
			json_close_object
			_ok=$((_ok + 1))
		fi
	else
		json_add_object
		json_add_string id ks
		json_add_string label "Kill switch"
		json_add_string detail "Disabled"
		json_add_string state skip
		json_add_string toggle f_privacy_enabled
		json_close_object
		_skip=$((_skip + 1))
	fi

	if sh_ok "grep -q privacy-killswitch-watchdog /etc/crontabs/root 2>/dev/null"; then
		json_add_object
		json_add_string id cron
		json_add_string label "Cron watchdog"
		json_add_string detail "Scheduled"
		json_add_string state ok
		json_close_object
		_ok=$((_ok + 1))
	else
		json_add_object
		json_add_string id cron
		json_add_string label "Cron watchdog"
		json_add_string detail "No crontab line"
		json_add_string state warn
		json_close_object
	fi

	_blk="$(uci_get glinet_privacy.tel.block_domains)"
	[ -z "$_blk" ] && _blk="0"
	if [ "$_blk" = "1" ]; then
		json_add_object
		json_add_string id tel
		json_add_string label "Telemetry DNS block"
		json_add_string detail "Enabled"
		json_add_string state ok
		json_add_string toggle f_block_domains
		json_close_object
		_ok=$((_ok + 1))
	else
		json_add_object
		json_add_string id tel
		json_add_string label "Telemetry DNS block"
		json_add_string detail "Off"
		json_add_string state skip
		json_add_string toggle f_block_domains
		json_close_object
		_skip=$((_skip + 1))
	fi

	if sh_ok "opkg list-installed 2>/dev/null | grep -q '^tor '" || sh_ok "command -v tor"; then
		json_add_object
		json_add_string id pkg_tor
		json_add_string label "tor package / binary"
		json_add_string detail "Present"
		json_add_string state ok
		json_close_object
		_ok=$((_ok + 1))
	else
		json_add_object
		json_add_string id pkg_tor
		json_add_string label "tor package / binary"
		json_add_string detail "Missing"
		json_add_string state warn
		json_close_object
	fi

	_disv="$(uci_get glinet_privacy.tel.disable_vendor_cloud)"
	[ -z "$_disv" ] && _disv="0"
	if [ "$_disv" = "1" ]; then
		json_add_object
		json_add_string id vendor_cloud
		json_add_string label "GL.iNet cloud"
		json_add_string detail "Disabled"
		json_add_string state ok
		json_add_string toggle f_disable_vendor
		json_close_object
		_ok=$((_ok + 1))
	else
		json_add_object
		json_add_string id vendor_cloud
		json_add_string label "GL.iNet cloud"
		json_add_string detail "Active"
		json_add_string state skip
		json_add_string toggle f_disable_vendor
		json_close_object
		_skip=$((_skip + 1))
	fi

	_rcp="$(uci_get glinet_privacy.tel.remove_cloud_packages)"
	[ -z "$_rcp" ] && _rcp="0"
	if [ "$_rcp" = "1" ]; then
		json_add_object
		json_add_string id cloud_pkgs
		json_add_string label "Cloud packages (opkg)"
		json_add_string detail "Removal enabled"
		json_add_string state ok
		json_add_string toggle f_remove_cloud_pkgs
		json_close_object
		_ok=$((_ok + 1))
	else
		json_add_object
		json_add_string id cloud_pkgs
		json_add_string label "Cloud packages (opkg)"
		json_add_string detail "Installed"
		json_add_string state skip
		json_add_string toggle f_remove_cloud_pkgs
		json_close_object
		_skip=$((_skip + 1))
	fi

	if uci -q show rotate_imei >/dev/null 2>&1; then
		_rie="$(uci_get rotate_imei.main.enabled)"
		[ -z "$_rie" ] && _rie="0"
		if [ "$_rie" = "1" ]; then
			json_add_object
			json_add_string id imei
			json_add_string label "IMEI rotation"
			json_add_string detail "Enabled on boot"
			json_add_string state ok
			json_add_string toggle f_rotate_imei
			json_close_object
			_ok=$((_ok + 1))
		else
			json_add_object
			json_add_string id imei
			json_add_string label "IMEI rotation"
			json_add_string detail "Disabled"
			json_add_string state skip
			json_add_string toggle f_rotate_imei
			json_close_object
			_skip=$((_skip + 1))
		fi
	fi

	json_close_array

	_denom=$((_ok + _bad))
	_pct=0
	if [ "$_denom" -gt 0 ]; then
		_pct=$((100 * _ok / _denom))
	fi
	json_add_int pct "$_pct"
	json_add_int ok_c "$_ok"
	json_add_int problem_c "$_bad"
	json_add_int skip_c "$_skip"
	json_add_int denom "$_denom"
	json_dump
}

# --- imei preview (simplified vs Lua) ---
json_imei_preview() {
	_ttys=""
	for _p in /dev/ttyUSB[0-9] /dev/ttyACM[0-3]; do
		[ -r "$_p" ] && _ttys="$_ttys $_p"
	done
	_slug="$(uci_get glinet_privacy.hw.slug)"
	if [ "$JSHN_OK" -eq 1 ]; then
		json_init
		json_add_string slug "$_slug"
		json_add_array tty_scan
		for _p in $_ttys; do
			[ -n "$_p" ] && json_add_string "" "$_p"
		done
		json_close_array
		json_add_array iface_list
		for _r in $(uci -q show network 2>/dev/null | sed -n "s/^network\.\([^.]*\)=interface\$/\1/p"); do
			[ "$_r" != "loopback" ] && [ -n "$_r" ] && json_add_string "" "$_r"
		done
		json_close_array
		json_add_array wwan_scan
		for _n in wwan 4g modem cellular; do
			uci -q get "network.$_n" >/dev/null 2>&1 && json_add_string "" "$_n"
		done
		json_close_array
		json_add_string preferred_modem "$(echo "$_ttys" | awk '{print $1}')"
		json_add_string preferred_wwan ""
		json_dump
	else
		die_json "no_jshn"
	fi
}

# --- vendor ubus (simplified) ---
json_vendor_ubus() {
	if ! uci -q show glinet_privacy >/dev/null 2>&1; then
		printf '%s\n' '{"active":false}'
		return 0
	fi
	_en="$(uci_get glinet_privacy.vendor_ubus.enabled)"
	[ "$_en" != "1" ] && printf '%s\n' '{"active":false}' && return 0

	_gate="$(uci_get glinet_privacy.vendor_ubus.min_release_substr)"
	_raw="$(ubus call system board 2>/dev/null || true)"
	_gated=0
	if [ -n "$_gate" ] && [ -n "$_raw" ] && ! echo "$_raw" | grep -qF "$_gate"; then
		_gated=1
	fi

	if [ "$JSHN_OK" -eq 1 ]; then
		json_init
		json_add_boolean active 1
		json_add_boolean gated "$_gated"
		json_add_string gate_substr "${_gate:-}"
		json_add_string board_release ""
		json_add_array probes
		json_add_object
		json_add_string id system_board
		json_add_string title "System board"
		json_add_boolean ok 1
		json_add_string output "$(echo "$_raw" | head -c 800)"
		json_close_object
		json_close_array
		json_dump
	else
		die_json "no_jshn"
	fi
}

# --- main ---
[ "$JSHN_OK" -eq 1 ] || die_json "no_jshn"

case "${1:-}" in
	overview) json_overview ;;
	net_probe) json_net_probe ;;
	privacy_log) json_privacy_log ;;
	imei_preview) json_imei_preview ;;
	vendor_ubus) json_vendor_ubus ;;
	verify_ip) json_verify_ip ;;
	*) die_json "bad_cmd" ;;
esac
