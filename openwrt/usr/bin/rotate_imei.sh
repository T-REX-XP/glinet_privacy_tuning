#!/bin/sh
# rotate_imei.sh — Generate a valid 15-digit IMEI (Luhn) and write to Quectel EG25-G NV.
# Requires: busybox awk, stty. Optional: TAC (8 digits) via env IMEI_TAC.
# WARNING: Altering IMEI may be illegal in your jurisdiction; use only where permitted.

set -eu

IMEI_TAC="${IMEI_TAC:-}"
MODEM_TTY="${MODEM_TTY:-}"
WWAN_IF="${WWAN_IF:-}"

log() {
	logger -t rotate_imei "$*" 2>/dev/null || echo "rotate_imei: $*"
}

# Luhn check digit for the first 14 digits (string of digits).
luhn_check_digit() {
	_body="$1"
	echo "$_body" | awk '{
		s = $0
		sum = 0
		for (i = length(s); i >= 1; i--) {
			d = substr(s, i, 1) + 0
			pos_from_right = length(s) - i + 1
			if (pos_from_right % 2 == 0) {
				d = d * 2
				if (d > 9) d = d - 9
			}
			sum += d
		}
		c = (10 - (sum % 10)) % 10
		print c
	}'
}

random_digits() {
	_n="$1"
	_out=""
	_i=0
	while [ "$_i" -lt "$_n" ]; do
		_out="${_out}$((RANDOM % 10))"
		_i=$((_i + 1))
	done
	printf '%s' "$_out"
}

generate_imei() {
	if [ -n "$IMEI_TAC" ]; then
		case "$IMEI_TAC" in
			*[!0-9]*)
				log "IMEI_TAC must contain only decimal digits"
				exit 1
				;;
		esac
		_len=${#IMEI_TAC}
		if [ "$_len" -ne 8 ]; then
			log "IMEI_TAC must be exactly 8 decimal digits"
			exit 1
		fi
		_serial="$(random_digits 6)"
		_body="${IMEI_TAC}${_serial}"
	else
		_body="$(random_digits 14)"
	fi
	_chk="$(luhn_check_digit "$_body")"
	printf '%s%s' "$_body" "$_chk"
}

find_modem_tty() {
	if [ -n "$MODEM_TTY" ] && [ -c "$MODEM_TTY" ]; then
		printf '%s' "$MODEM_TTY"
		return 0
	fi
	for _t in /dev/ttyUSB2 /dev/ttyUSB3 /dev/ttyUSB1 /dev/ttyUSB0; do
		if [ -c "$_t" ]; then
			printf '%s' "$_t"
			return 0
		fi
	done
	return 1
}

send_at_imei() {
	_tty="$1"
	_imei="$2"
	if [ ! -w "$_tty" ]; then
		log "Cannot write to $_tty"
		exit 1
	fi
	stty -F "$_tty" 115200 cs8 -cstopb -parenb raw -echo 2>/dev/null || true
	# Quectel: write IMEI to NV (may require engineering firmware / permissions).
	_resp="$(mktemp)"
	( printf 'AT+EGMR=1,7,"%s"\r\n' "$_imei" > "$_tty"; sleep 0.5; timeout 2 cat "$_tty" > "$_resp" ) 2>/dev/null || true
	if grep -q 'OK' "$_resp" 2>/dev/null; then
		rm -f "$_resp"
		return 0
	fi
	log "AT response (check permissions / firmware): $(cat "$_resp" 2>/dev/null | tr -d '\r' | head -c 200)"
	rm -f "$_resp"
	return 1
}

detect_wwan_if() {
	if [ -n "$WWAN_IF" ]; then
		printf '%s' "$WWAN_IF"
		return 0
	fi
	# Common on OpenWrt / GL.iNet cellular
	for _c in wwan 4g modem cellular; do
		if uci -q get "network.${_c}.device" >/dev/null 2>&1 || \
		   uci -q get "network.${_c}.ifname" >/dev/null 2>&1; then
			printf '%s' "$_c"
			return 0
		fi
	done
	printf '%s' "wwan"
}

restart_modem_iface() {
	_if="$(detect_wwan_if)"
	log "Restarting network interface: $_if"
	if command -v ifdown >/dev/null 2>&1; then
		ifdown "$_if" 2>/dev/null || true
		sleep 2
		ifup "$_if" 2>/dev/null || /etc/init.d/network reload 2>/dev/null || true
	else
		/etc/init.d/network reload 2>/dev/null || true
	fi
}

main() {
	# Busybox ash has RANDOM when built with it; fallback.
	if [ "${RANDOM:-0}" -eq 0 ] 2>/dev/null; then
		RANDOM="$(awk 'BEGIN{srand(); print int(32767*rand())}')"
	fi
	_imei="$(generate_imei)"
	log "Generated IMEI (Luhn-valid): $_imei"

	_tty="$(find_modem_tty)" || {
		log "No modem serial device found (set MODEM_TTY)"
		exit 1
	}
	log "Using modem TTY: $_tty"

	if send_at_imei "$_tty" "$_imei"; then
		log "AT+EGMR accepted"
	else
		log "AT+EGMR may have failed; continuing with interface restart anyway"
	fi
	restart_modem_iface
}

main "$@"
