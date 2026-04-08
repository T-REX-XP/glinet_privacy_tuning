#!/bin/sh
# apply-mullvad-wireguard.sh — Apply Mullvad WireGuard client via UCI (OpenWrt).
# Export secrets from https://mullvad.net/account — requires wireguard-tools, kmod-wireguard.

set -eu

MULLVAD_PRIVATE_KEY="${MULLVAD_PRIVATE_KEY:?set MULLVAD_PRIVATE_KEY}"
MULLVAD_ADDRESS="${MULLVAD_ADDRESS:?set MULLVAD_ADDRESS}"   # e.g. 10.x.x.x/32
MULLVAD_PUBLIC_KEY="${MULLVAD_PUBLIC_KEY:?set MULLVAD_PUBLIC_KEY}"
MULLVAD_ENDPOINT="${MULLVAD_ENDPOINT:-}"
MULLVAD_ENDPOINT_HOST="${MULLVAD_ENDPOINT_HOST:-}"
MULLVAD_ENDPOINT_PORT="${MULLVAD_ENDPOINT_PORT:-51820}"
MULLVAD_ALLOWED_IPS="${MULLVAD_ALLOWED_IPS:-0.0.0.0/0,::/0}"
MULLVAD_DNS="${MULLVAD_DNS:-10.64.0.1}"

WG_IF="${WG_IF:-wg0}"
WG_MTU="${WG_MTU:-1380}"
PEER_SECTION="${PEER_SECTION:-mullvad0}"

die() {
	echo "$*" >&2
	exit 1
}

command -v uci >/dev/null 2>&1 || die "uci not found"

if [ -n "$MULLVAD_ENDPOINT" ]; then
	# IPv4 host:port only; for IPv6 use MULLVAD_ENDPOINT_HOST / MULLVAD_ENDPOINT_PORT.
	MULLVAD_ENDPOINT_HOST="${MULLVAD_ENDPOINT_HOST:-${MULLVAD_ENDPOINT%:*}}"
	MULLVAD_ENDPOINT_PORT="${MULLVAD_ENDPOINT_PORT:-${MULLVAD_ENDPOINT##*:}}"
fi
[ -n "$MULLVAD_ENDPOINT_HOST" ] || die "Set MULLVAD_ENDPOINT or MULLVAD_ENDPOINT_HOST"

# Remove prior wg interface and peer (same names)
uci -q delete "network.${WG_IF}"
uci -q delete "network.${PEER_SECTION}"

uci set "network.${WG_IF}=interface"
uci set "network.${WG_IF}.proto='wireguard'"
uci set "network.${WG_IF}.private_key='${MULLVAD_PRIVATE_KEY}'"
uci add_list "network.${WG_IF}.addresses=${MULLVAD_ADDRESS}"
uci set "network.${WG_IF}.mtu='${WG_MTU}'"

uci set "network.${PEER_SECTION}=wireguard_${WG_IF}"
uci set "network.${PEER_SECTION}.description='Mullvad'"
uci set "network.${PEER_SECTION}.public_key='${MULLVAD_PUBLIC_KEY}'"
uci set "network.${PEER_SECTION}.allowed_ips='${MULLVAD_ALLOWED_IPS}'"
uci set "network.${PEER_SECTION}.endpoint_host='${MULLVAD_ENDPOINT_HOST}'"
uci set "network.${PEER_SECTION}.endpoint_port='${MULLVAD_ENDPOINT_PORT}'"
uci set "network.${PEER_SECTION}.persistent_keepalive='25'"

# Attach ${WG_IF} to firewall wan zone
WAN_ZONE="$(uci show firewall 2>/dev/null | sed -n "s/^firewall\.\([^.]*\)\.name='wan'$/\1/p" | head -1)"
if [ -n "$WAN_ZONE" ]; then
	_netlist="$(uci -q get "firewall.${WAN_ZONE}.network" 2>/dev/null || true)"
	case " ${_netlist} " in
		*" ${WG_IF} "*) ;;
		*)
			if uci -q get "firewall.${WAN_ZONE}.network" >/dev/null 2>&1; then
				uci add_list "firewall.${WAN_ZONE}.network=${WG_IF}" 2>/dev/null || \
					uci set "firewall.${WAN_ZONE}.network=${_netlist} ${WG_IF}"
			else
				uci add_list "firewall.${WAN_ZONE}.network=${WG_IF}"
			fi
			;;
	esac
else
	uci set firewall.wg_priv=zone
	uci set firewall.wg_priv.name='wg_priv'
	uci set firewall.wg_priv.input='REJECT'
	uci set firewall.wg_priv.output='ACCEPT'
	uci set firewall.wg_priv.forward='REJECT'
	uci set firewall.wg_priv.masq='1'
	uci set firewall.wg_priv.mtu_fix='1'
	uci add_list firewall.wg_priv.network="${WG_IF}"
	uci set firewall.wg_priv_lan=forwarding
	uci set firewall.wg_priv_lan.src='lan'
	uci set firewall.wg_priv_lan.dest='wg_priv'
fi

uci -q delete dhcp.@dnsmasq[0].server 2>/dev/null || true
uci add_list "dhcp.@dnsmasq[0].server=${MULLVAD_DNS}"
uci set dhcp.@dnsmasq[0].noresolv='1'

uci commit network
uci commit firewall
uci commit dhcp

echo "Applied Mullvad WireGuard (${WG_IF}). Run: /etc/init.d/network reload; /etc/init.d/firewall reload; /etc/init.d/dnsmasq restart"
