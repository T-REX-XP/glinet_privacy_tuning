#!/bin/sh
# disable-glinet-telemetry.sh — Best-effort UCI toggles for GL.iNet cloud/telemetry (firmware-dependent).
# Reference behaviour: glconfig.cloud.enable=0, gl_cloud stop/disable, DNS blocks via apply-telemetry.sh + dnsmasq.d.

set -eu

log() {
	logger -t glinet-telemetry "$*" 2>/dev/null || echo "glinet-telemetry: $*"
}

uci_safe_set() {
	uci -q set "$1" 2>/dev/null && log "set $1" || true
}

# Stock GL.iNet: GoodCloud / remote management (see glconfig; names vary by release).
if uci -q show glconfig >/dev/null 2>&1; then
	uci set glconfig.cloud.enable='0' 2>/dev/null || true
	log "set glconfig.cloud.enable=0 (best-effort)"
	uci -q commit glconfig 2>/dev/null || true
fi

# Other common keys — only touch options that already exist (avoids invalid sections).
for _p in \
	glconfig.general.cloud_enable=0 \
	glconfig.general.enable_cloud=0 \
	glconfig.general.goodcloud=0 \
	glinet.gl_cloud=0 \
	glinet.cloud_enabled=0 \
	goodcloud.global.enable=0 \
	goodcloud.main.enable=0
do
	_k="${_p%%=*}"
	_v="${_p#*=}"
	if uci -q get "$_k" >/dev/null 2>&1; then
		uci_safe_set "${_k}=${_v}"
	fi
done

# Stop / disable vendor services if present
for _svc in gl_cloud goodcloud glinet_cloud gl_modem_tracker gl-modem-tracking; do
	if [ -x "/etc/init.d/${_svc}" ]; then
		"/etc/init.d/${_svc}" stop 2>/dev/null || true
		"/etc/init.d/${_svc}" disable 2>/dev/null || true
		log "stopped ${_svc}"
	fi
done

# Optional: remove GL.iNet cloud-related packages (LuCI: glinet_privacy.tel.remove_cloud_packages)
REMOVE_PKGS="$(uci -q get glinet_privacy.tel.remove_cloud_packages 2>/dev/null || echo 0)"
case "$REMOVE_PKGS" in
	1|true|yes|on)
		if command -v opkg >/dev/null 2>&1; then
			for _pkg in gl-cloud gl-router-plugin-cloud gl-sdk-cloud goodcloud; do
				if opkg list-installed 2>/dev/null | grep -q "^${_pkg} "; then
					if opkg remove "$_pkg" 2>/dev/null; then
						log "removed opkg package ${_pkg}"
					else
						log "opkg remove ${_pkg} failed (ignored)"
					fi
				fi
			done
		fi
		;;
esac

uci commit 2>/dev/null || true
log "Done (verify: uci show glconfig 2>/dev/null | grep -i cloud; opkg list-installed | grep -iE 'cloud|good' || true)"
