#!/bin/sh
# Registers glinet-privacy with OpenWrt firewall (fw3/fw4) and adds a GL.iNet-style
# /etc/firewall.user hook. Some firmware upgrades reset UCI firewall includes; the
# firewall.user line still runs fw-plugin.sh on each firewall reload (rules are idempotent).

set -eu

uci set firewall.glinet_privacy=include
uci set firewall.glinet_privacy.path='/usr/libexec/glinet-privacy/fw-plugin.sh'
uci set firewall.glinet_privacy.reload='1'
uci set firewall.glinet_privacy.enabled='1'
uci -q delete firewall.privacy_tor 2>/dev/null || true

uci commit firewall

# Companion "plugin" hook (marker: glinet-privacy-fw-plugin)
F=/etc/firewall.user
[ -f "$F" ] || touch "$F"
if ! grep -qF 'glinet-privacy-fw-plugin' "$F" 2>/dev/null; then
	printf '\n# glinet-privacy-fw-plugin (see /usr/libexec/glinet-privacy/fw-plugin.sh)\n' >> "$F"
	printf '[ -x /usr/libexec/glinet-privacy/fw-plugin.sh ] && /usr/libexec/glinet-privacy/fw-plugin.sh\n' >> "$F"
fi

echo "Registered firewall.glinet_privacy + firewall.user hook. Run: /etc/init.d/firewall reload"
