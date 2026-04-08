#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# NAT redirects for transparent Tor — sourced by glinet-privacy fw-plugin when enabled.
# Values from UCI glinet_privacy.firewall.main, then network.lan, then defaults.

set -eu

LAN_DEV="$(uci -q get glinet_privacy.tor.lan_dev 2>/dev/null || true)"
[ -n "$LAN_DEV" ] || LAN_DEV="$(uci -q get network.lan.device 2>/dev/null || echo br-lan)"

ROUTER_LAN_IP="$(uci -q get glinet_privacy.tor.router_lan_ip 2>/dev/null || true)"
[ -n "$ROUTER_LAN_IP" ] || ROUTER_LAN_IP="$(uci -q get network.lan.ipaddr 2>/dev/null || echo 192.168.8.1)"

LAN_CIDR="$(uci -q get glinet_privacy.tor.lan_cidr 2>/dev/null || echo 192.168.8.0/24)"
TOR_TRANS_PORT="$(uci -q get glinet_privacy.tor.tor_trans_port 2>/dev/null || echo 9040)"
TOR_DNS_PORT="$(uci -q get glinet_privacy.tor.tor_dns_port 2>/dev/null || echo 9053)"
REDIR_TCP_DNS="$(uci -q get glinet_privacy.dns.redirect_tcp_dns 2>/dev/null || echo 1)"
BLOCK_DOT="$(uci -q get glinet_privacy.dns.block_lan_dot 2>/dev/null || echo 0)"

iptables -t nat -C PREROUTING -i "$LAN_DEV" -p tcp ! -d "$LAN_CIDR" -j REDIRECT --to-ports "$TOR_TRANS_PORT" 2>/dev/null || \
	iptables -t nat -I PREROUTING -i "$LAN_DEV" -p tcp ! -d "$LAN_CIDR" -j REDIRECT --to-ports "$TOR_TRANS_PORT"

iptables -t nat -C PREROUTING -i "$LAN_DEV" -p udp --dport 53 ! -d "$ROUTER_LAN_IP" -j REDIRECT --to-ports "$TOR_DNS_PORT" 2>/dev/null || \
	iptables -t nat -I PREROUTING -i "$LAN_DEV" -p udp --dport 53 ! -d "$ROUTER_LAN_IP" -j REDIRECT --to-ports "$TOR_DNS_PORT"

case "$REDIR_TCP_DNS" in
	1|true|yes|on)
		iptables -t nat -C PREROUTING -i "$LAN_DEV" -p tcp --dport 53 ! -d "$ROUTER_LAN_IP" -j REDIRECT --to-ports "$TOR_DNS_PORT" 2>/dev/null || \
			iptables -t nat -I PREROUTING -i "$LAN_DEV" -p tcp --dport 53 ! -d "$ROUTER_LAN_IP" -j REDIRECT --to-ports "$TOR_DNS_PORT"
		;;
esac

case "$BLOCK_DOT" in
	1|true|yes|on)
		iptables -C FORWARD -i "$LAN_DEV" -p tcp ! -d "$ROUTER_LAN_IP" --dport 853 -j DROP 2>/dev/null || \
			iptables -I FORWARD -i "$LAN_DEV" -p tcp ! -d "$ROUTER_LAN_IP" --dport 853 -j DROP
		;;
esac

exit 0
