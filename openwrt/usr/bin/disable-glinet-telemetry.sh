#!/bin/sh
# disable-glinet-telemetry.sh — Best-effort UCI toggles for GL.iNet cloud/telemetry (firmware-dependent).

set -eu

log() {
	logger -t glinet-telemetry "$*" 2>/dev/null || echo "glinet-telemetry: $*"
}

uci_safe_set() {
	uci -q set "$1" 2>/dev/null && log "set $1" || true
}

uci_safe_del() {
	uci -q delete "$1" 2>/dev/null && log "delete $1" || true
}

# Common GL.iNet / vendor keys (names vary by release — ignore failures).
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

uci commit 2>/dev/null || true
log "Done (verify with: uci show | grep -iE 'cloud|good')"
