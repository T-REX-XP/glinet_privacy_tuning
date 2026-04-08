#!/bin/sh
# firewall.privacy-tor.sh — NAT redirects for transparent Tor (iptables/xtables-nft).
# UCI include: see apply-privacy-firewall-includes.sh
# Override: LAN_CIDR, ROUTER_LAN_IP, LAN_DEV, TOR_TRANS_PORT, TOR_DNS_PORT

set -eu

LAN_DEV="${LAN_DEV:-$(uci -q get network.lan.device || echo br-lan)}"
ROUTER_LAN_IP="${ROUTER_LAN_IP:-$(uci -q get network.lan.ipaddr || echo 192.168.8.1)}"
LAN_CIDR="${LAN_CIDR:-192.168.8.0/24}"
TOR_TRANS_PORT="${TOR_TRANS_PORT:-9040}"
TOR_DNS_PORT="${TOR_DNS_PORT:-9053}"

iptables -t nat -C PREROUTING -i "$LAN_DEV" -p tcp ! -d "$LAN_CIDR" -j REDIRECT --to-ports "$TOR_TRANS_PORT" 2>/dev/null || \
	iptables -t nat -I PREROUTING -i "$LAN_DEV" -p tcp ! -d "$LAN_CIDR" -j REDIRECT --to-ports "$TOR_TRANS_PORT"

iptables -t nat -C PREROUTING -i "$LAN_DEV" -p udp --dport 53 ! -d "$ROUTER_LAN_IP" -j REDIRECT --to-ports "$TOR_DNS_PORT" 2>/dev/null || \
	iptables -t nat -I PREROUTING -i "$LAN_DEV" -p udp --dport 53 ! -d "$ROUTER_LAN_IP" -j REDIRECT --to-ports "$TOR_DNS_PORT"

exit 0
