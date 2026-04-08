#!/bin/sh
# Registers the glinet-privacy firewall include (OpenWrt fw3/fw4).

set -eu

uci set firewall.glinet_privacy=include
uci set firewall.glinet_privacy.path='/usr/libexec/glinet-privacy/fw-plugin.sh'
uci set firewall.glinet_privacy.reload='1'
uci set firewall.glinet_privacy.enabled='1'
uci -q delete firewall.privacy_tor 2>/dev/null || true

uci commit firewall
echo "Registered firewall.glinet_privacy. Run: /etc/init.d/firewall reload"
