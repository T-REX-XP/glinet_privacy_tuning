#!/bin/sh
# Registers firewall includes for Tor NAT + optional custom chain (OpenWrt fw3/fw4).

set -eu

uci set firewall.privacy_tor=include
uci set firewall.privacy_tor.path='/etc/firewall.privacy-tor.sh'
uci set firewall.privacy_tor.reload='1'
uci set firewall.privacy_tor.enabled='1'

uci commit firewall
echo "Committed firewall.privacy_tor include. Run: /etc/init.d/firewall reload"
