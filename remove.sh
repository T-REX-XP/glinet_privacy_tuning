#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# glinet_puli_privacy — remove glinet-privacy and LuCI app files from OpenWrt / GL.iNet.
# Reverses a typical install.sh run: stops watchdog, flushes killswitch rules, removes
# firewall hooks, crontab lines, Tor include, dnsmasq symlink, UCI configs, and package files.
#
#   sh remove.sh
#   sh remove.sh --opkg          # also: opkg remove luci-app-glinet-privacy glinet-privacy (if present)
#
# Same source discovery as install.sh:
#   GLINET_PRIVACY_SRC=/path/to/repo sh remove.sh
#   or run from a git clone next to package/glinet-privacy/files
#
# Remote (script only, no tree): uses a built-in file list — OK if paths match your install.

set -eu

DO_OPKG=0
CLEANUP_DIR=""
REPO_ROOT=""

log() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

print_help() {
	cat <<'EOF'
glinet_puli_privacy remove.sh

  sh remove.sh [--opkg]

  --opkg        After file removal, run: opkg remove luci-app-glinet-privacy glinet-privacy
                (only if those packages are installed; ignores errors)

Requires root. Stops privacy-killswitch (flushes iptables), disables services, removes
firewall.glinet_privacy, edits /etc/firewall.user, strips cron lines for this project,
removes Tor %include for 99-transparent.conf, /etc/dnsmasq.d/glinet-block.conf link,
and deletes /etc/config/{privacy,glinet_privacy,rotate_imei} after removing files.

Does not uninstall opkg dependencies (tor, wireguard-tools, …) unless you use --opkg
for our ipk packages only.
EOF
}

for _arg in "$@"; do
	case "$_arg" in
		--opkg) DO_OPKG=1 ;;
		-h|--help) print_help; exit 0 ;;
		*) die "Unknown option: $_arg" ;;
	esac
done

[ "$(id -u)" -eq 0 ] || die "Run as root (e.g. ssh root@router && sh remove.sh)"

[ -f /etc/openwrt_release ] || log "Warning: /etc/openwrt_release not found — not OpenWrt?"

mktemp_dir() {
	if command -v mktemp >/dev/null 2>&1; then
		mktemp -d /tmp/glinet-privacy-remove.XXXXXX 2>/dev/null || echo "/tmp/glinet-privacy-remove-$$"
	else
		_d="/tmp/glinet-privacy-remove-$$"
		mkdir -p "$_d"
		echo "$_d"
	fi
}

resolve_source() {
	if [ -n "${GLINET_PRIVACY_SRC:-}" ]; then
		[ -d "$GLINET_PRIVACY_SRC/package/glinet-privacy/files" ] \
			|| die "GLINET_PRIVACY_SRC invalid: missing package/glinet-privacy/files"
		REPO_ROOT="$GLINET_PRIVACY_SRC"
		return
	fi

	_script="$0"
	case "$_script" in
		*remove.sh)
			if [ -f "$_script" ] && [ -r "$_script" ]; then
				_dir="$(CDPATH= cd "$(dirname "$_script")" && pwd)"
				if [ -d "$_dir/package/glinet-privacy/files" ]; then
					REPO_ROOT="$_dir"
					return
				fi
			fi
			;;
	esac

	if [ -n "${GLINET_PRIVACY_GIT_URL:-}" ]; then
		command -v git >/dev/null 2>&1 || die "git not found; set GLINET_PRIVACY_SRC"
		CLEANUP_DIR="$(mktemp_dir)"
		mkdir -p "$CLEANUP_DIR"
		git clone --depth 1 --branch "${GLINET_PRIVACY_BRANCH:-main}" "$GLINET_PRIVACY_GIT_URL" "$CLEANUP_DIR/repo" \
			|| git clone --depth 1 "$GLINET_PRIVACY_GIT_URL" "$CLEANUP_DIR/repo" \
			|| die "git clone failed"
		REPO_ROOT="$CLEANUP_DIR/repo"
		return
	fi

	if [ -n "${GLINET_PRIVACY_TARBALL_URL:-}" ]; then
		command -v tar >/dev/null 2>&1 || die "tar not found"
		CLEANUP_DIR="$(mktemp_dir)"
		mkdir -p "$CLEANUP_DIR/out"
		_tgz="$CLEANUP_DIR/src.tar.gz"
		if command -v wget >/dev/null 2>&1; then
			wget -qO "$_tgz" "$GLINET_PRIVACY_TARBALL_URL" || die "wget failed"
		elif command -v curl >/dev/null 2>&1; then
			curl -fsSL "$GLINET_PRIVACY_TARBALL_URL" -o "$_tgz" || die "curl failed"
		else
			die "Need wget or curl"
		fi
		( cd "$CLEANUP_DIR/out" && tar xzf "$_tgz" ) || die "tar extract failed"
		for _d in "$CLEANUP_DIR/out"/*; do
			[ -d "$_d" ] || continue
			[ -d "$_d/package/glinet-privacy/files" ] \
				|| die "Archive must contain package/glinet-privacy/files"
			REPO_ROOT="$_d"
			return
		done
		die "Empty archive?"
	fi

	REPO_ROOT=""
}

cleanup() {
	[ -n "$CLEANUP_DIR" ] && [ -d "$CLEANUP_DIR" ] && rm -rf "$CLEANUP_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

stop_services() {
	if [ -x /etc/init.d/privacy-killswitch ]; then
		log "Stopping privacy-killswitch (flush killswitch rules)"
		/etc/init.d/privacy-killswitch stop 2>/dev/null || true
		/etc/init.d/privacy-killswitch disable 2>/dev/null || true
	fi
	if [ -x /etc/init.d/rotate_imei ]; then
		/etc/init.d/rotate_imei disable 2>/dev/null || true
	fi
}

clean_firewall_uci() {
	if uci -q get firewall.glinet_privacy >/dev/null 2>&1; then
		log "Removing firewall.glinet_privacy"
		uci -q delete firewall.glinet_privacy
		uci commit firewall 2>/dev/null || true
	fi
}

clean_firewall_user() {
	F=/etc/firewall.user
	[ -f "$F" ] || return 0
	if ! grep -q 'glinet-privacy' "$F" 2>/dev/null; then
		return 0
	fi
	log "Editing /etc/firewall.user (remove glinet-privacy lines)"
	_tmp="${F}.tmp.$$"
	grep -v 'glinet-privacy' "$F" > "$_tmp" && mv -f "$_tmp" "$F" || rm -f "$_tmp"
}

clean_crontab() {
	_cr="/etc/crontabs/root"
	[ -f "$_cr" ] || return 0
	if ! grep -q 'privacy-killswitch-watchdog' "$_cr" 2>/dev/null \
		&& ! grep -q '/usr/bin/rotate_imei.sh' "$_cr" 2>/dev/null; then
		return 0
	fi
	log "Removing glinet-privacy lines from /etc/crontabs/root"
	_tmp="${_cr}.tmp.$$"
	grep -v 'privacy-killswitch-watchdog.sh' "$_cr" | grep -v '/usr/bin/rotate_imei.sh' > "$_tmp" && mv -f "$_tmp" "$_cr" || rm -f "$_tmp"
}

clean_torrc() {
	[ -f /etc/tor/torrc ] || return 0
	if ! grep -q 'glinet-privacy\|99-transparent.conf' /etc/tor/torrc 2>/dev/null; then
		return 0
	fi
	log "Removing glinet-privacy include from /etc/tor/torrc"
	_tmp="/etc/tor/torrc.tmp.$$"
	grep -v '/etc/tor/torrc.d/99-transparent.conf' /etc/tor/torrc | grep -v '# glinet-privacy' > "$_tmp" && mv -f "$_tmp" /etc/tor/torrc || rm -f "$_tmp"
}

clean_dnsmasq_block() {
	if [ -L /etc/dnsmasq.d/glinet-block.conf ] || [ -f /etc/dnsmasq.d/glinet-block.conf ]; then
		log "Removing /etc/dnsmasq.d/glinet-block.conf"
		rm -f /etc/dnsmasq.d/glinet-block.conf
	fi
}

# Embedded list when REPO_ROOT is unavailable (must match package/glinet-privacy/files layout).
remove_files_builtin() {
	for _r in \
		etc/config/privacy \
		etc/config/glinet_privacy \
		etc/config/rotate_imei \
		etc/crontabs/root.privacy.example \
		etc/crontabs/root.rotate_imei.example \
		etc/firewall.privacy-tor.sh \
		etc/glinet-privacy/glinet-block.conf \
		etc/init.d/privacy-killswitch \
		etc/init.d/rotate_imei \
		etc/tor/torrc.d/99-transparent.conf \
		etc/uci-defaults/99-glinet-privacy-device \
		etc/uci-defaults/99-glinet-privacy-firewall \
		usr/bin/apply-privacy-firewall-includes.sh \
		usr/bin/disable-glinet-telemetry.sh \
		usr/bin/privacy-killswitch-watchdog.sh \
		usr/bin/rotate_imei.sh \
		usr/libexec/glinet-privacy/apply-device-profile.sh \
		usr/libexec/glinet-privacy/apply-dns-policy.sh \
		usr/libexec/glinet-privacy/apply-telemetry.sh \
		usr/libexec/glinet-privacy/apply-rotate-imei-cron.sh \
		usr/libexec/glinet-privacy/apply-vendor-vpn-killswitch.sh \
		usr/libexec/glinet-privacy/fw-plugin.sh \
		usr/libexec/glinet-privacy/killswitch-drop-active.sh \
		usr/libexec/glinet-privacy/tor-transparent-nat-active.sh \
		usr/share/glinet-privacy/version.mk
	do
		if [ -f "/$_r" ] || [ -L "/$_r" ]; then
			rm -f "/$_r"
		fi
	done
}

remove_core_from_tree() {
	_SRC="$REPO_ROOT/package/glinet-privacy/files"
	[ -d "$_SRC" ] || die "Missing $_SRC"
	log "Removing files from package tree: $_SRC"
	( cd "$_SRC" && find . -type f ) | while IFS= read -r _r; do
		_r="${_r#./}"
		[ -n "$_r" ] || continue
		if [ -f "/$_r" ] || [ -L "/$_r" ]; then
			rm -f "/$_r"
		fi
	done
}

remove_core() {
	if [ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/package/glinet-privacy/files" ]; then
		remove_core_from_tree
	else
		log "No source tree; using built-in file list"
		remove_files_builtin
	fi
	rm -f /etc/glinet-privacy/.telemetry-seeded 2>/dev/null || true
}

rmdir_empty() {
	for _d in \
		/usr/libexec/glinet-privacy \
		/usr/share/glinet-privacy \
		/etc/glinet-privacy \
		/etc/tor/torrc.d
	do
		rmdir "$_d" 2>/dev/null || true
	done
}

remove_luci() {
	log "Removing LuCI app files"
	rm -f /usr/share/luci/menu.d/luci-app-glinet-privacy.json
	rm -f /usr/share/glinet-privacy/luci-use-menu-d
	rm -f /usr/lib/lua/luci/controller/glinet_privacy.lua
	rm -rf /usr/lib/lua/luci/model/cbi/glinet_privacy
	rm -rf /usr/lib/lua/luci/view/glinet_privacy
	rm -rf /usr/lib/lua/luci/glinet_privacy
	rm -f /usr/share/rpcd/acl.d/luci-app-glinet-privacy.json
	# ipk installs compiled catalogs
	for _l in /usr/lib/lua/luci/i18n/glinet_privacy.*.lmo; do
		[ -f "$_l" ] && rm -f "$_l"
	done
}

maybe_opkg_remove() {
	[ "$DO_OPKG" -eq 1 ] || return 0
	command -v opkg >/dev/null 2>&1 || { log "opkg not found; skip --opkg"; return 0; }
	log "opkg remove (if installed): luci-app-glinet-privacy glinet-privacy"
	opkg remove luci-app-glinet-privacy glinet-privacy 2>/dev/null || log "opkg remove finished (packages may be absent)"
}

restart_services() {
	/etc/init.d/firewall reload 2>/dev/null || true
	/etc/init.d/dnsmasq restart 2>/dev/null || true
	/etc/init.d/cron restart 2>/dev/null || true
	/etc/init.d/tor restart 2>/dev/null || true
	/etc/init.d/rpcd restart 2>/dev/null || true
	/etc/init.d/uhttpd restart 2>/dev/null || true
}

resolve_source
log "Using repo root: ${REPO_ROOT:-"(none — built-in list)"}"

stop_services
clean_firewall_uci
clean_firewall_user
clean_crontab
clean_torrc
clean_dnsmasq_block
remove_core
rmdir_empty
remove_luci
maybe_opkg_remove
restart_services

log "Done. glinet-privacy files and hooks removed. Tor/dnsmasq/opkg packages were not uninstalled unless you used --opkg."
