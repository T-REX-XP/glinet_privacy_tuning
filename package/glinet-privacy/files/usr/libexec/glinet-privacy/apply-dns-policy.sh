#!/bin/sh
# apply-dns-policy.sh — Point dnsmasq at Tor DNSPort when dns_policy=tor_dnsmasq (reduces ISP DNS leaks).

set -eu

POLICY="$(uci -q get glinet_privacy.dns.dns_policy 2>/dev/null || echo default)"
TOR_DNS="$(uci -q get glinet_privacy.tor.tor_dns_port 2>/dev/null || echo 9053)"
DMQ="dhcp.@dnsmasq[0]"

if ! uci -q get "$DMQ" >/dev/null 2>&1; then
	logger -t glinet-dns-policy "no dhcp.@dnsmasq[0]; skip" 2>/dev/null || true
	exit 0
fi

case "$POLICY" in
	tor_dnsmasq)
		uci -q delete "${DMQ}.server" 2>/dev/null || true
		uci add_list "${DMQ}.server=127.0.0.1#${TOR_DNS}"
		uci set "${DMQ}.noresolv=1"
		uci commit dhcp
		logger -t glinet-dns-policy "dnsmasq -> 127.0.0.1#${TOR_DNS} (Tor DNSPort); noresolv=1" 2>/dev/null || true
		;;
	default|*)
		exit 0
		;;
esac

exit 0
