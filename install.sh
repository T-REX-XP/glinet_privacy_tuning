#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# glinet_puli_privacy — one-shot installer for GL.iNet routers (POSIX sh; stock GL.iNet / OpenWrt-based firmware).
#
# Default: copies package files, registers firewall, applies device profile, installs
# optional opkg packages, merges Tor config, enables services, cron watchdog, telemetry.
#
#   sh install.sh
#   sh install.sh --without-luci
#   sh install.sh --minimal
#
# Remote: you must fetch the script with curl or wget first — do not paste only the https URL
#   (ash will report "not found" because the URL is not an executable).
#   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | \
#     GLINET_PRIVACY_TARBALL_URL=https://github.com/USER/REPO/archive/refs/heads/main.tar.gz sh -s --
#   wget -qO- https://raw.githubusercontent.com/USER/REPO/main/install.sh | \
#     GLINET_PRIVACY_TARBALL_URL=... sh -s --
#
# Optional flags:
#   --minimal          Only copy files + firewall + device profile (no opkg/Tor/cron/telemetry)
#   --without-luci     Skip installing LuCI app files (default is to install them)
#   --with-imei-boot   Enable rotate_imei on boot (uci + init.d)
#   --with-imei-cron    Enable UCI cron (default 6h); change interval in LuCI → IMEI rotation
#
# Env: GLINET_PRIVACY_SRC, GLINET_PRIVACY_GIT_URL, GLINET_PRIVACY_TARBALL_URL,
#      GLINET_PRIVACY_BRANCH (default main)
#      GLINET_PRIVACY_SKIP_OPKG_UPDATE=1 — skip opkg update (faster re-runs; install may fail if feeds stale)
# opkg: uses "iptables-nft" as satisfying the iptables stack when present; tor-fw-helper is optional (not in all feeds).
#      Install uses plain "opkg install" (no -V0); some vendor opkg builds reject "-V 0" and print usage.
#      GLINET_PRIVACY_FORCE_TELEMETRY_SEED=1 — re-apply installer telemetry UCI defaults (normally once only)
#      GLINET_PRIVACY_LUCI_MENU_JSON=auto|1|0 — menu.d JSON (default auto: off, Lua index(); use 1 for JSON menu)
#
# Package version: package/version.mk
#
# Uninstall: see remove.sh (stops services, removes hooks, files, and UCI configs).

set -eu

BRANCH="${GLINET_PRIVACY_BRANCH:-main}"
INSTALL_LUCI=1
MINIMAL=0
IMEI_BOOT=0
IMEI_CRON=0
CLEANUP_DIR=""
REPO_ROOT=""

log() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

print_help() {
	cat <<'EOF'
glinet_puli_privacy install.sh

  sh install.sh [--without-luci] [--minimal] [--with-imei-boot] [--with-imei-cron]

Supported: GL.iNet routers with stock firmware only. Default install applies: opkg deps (if available),
Tor torrc merge, killswitch cron, telemetry blocklist + dnsmasq confdir, init.d services, LuCI UI files.

  --minimal           Skip opkg/Tor/cron/telemetry automation (files + firewall only)
  --without-luci      Do not install LuCI UI files
  --with-luci         Install LuCI UI files (default; kept for compatibility)
  --with-imei-boot    Enable IMEI rotation on boot (cellular routers; legal risk — see docs/devices.md)
  --with-imei-cron    Enable scheduled IMEI rotation (default every 6h; edit interval in LuCI)

Remote: GLINET_PRIVACY_TARBALL_URL=... or GLINET_PRIVACY_GIT_URL=...

Re-runs: safe (skips opkg update when deps satisfied; telemetry seed once; dhcp confdir not duplicated).

Env: GLINET_PRIVACY_SKIP_OPKG_UPDATE=1  GLINET_PRIVACY_FORCE_TELEMETRY_SEED=1  GLINET_PRIVACY_LUCI_MENU_JSON=auto|1|0
  LuCI requires luci-lua-runtime (installed automatically when opkg is available; install aborts if missing when LuCI is enabled).
EOF
}

for _arg in "$@"; do
	case "$_arg" in
		--with-luci) INSTALL_LUCI=1 ;;
		--without-luci) INSTALL_LUCI=0 ;;
		--minimal) MINIMAL=1 ;;
		--with-imei-boot) IMEI_BOOT=1 ;;
		--with-imei-cron) IMEI_CRON=1 ;;
		-h|--help) print_help; exit 0 ;;
		*) die "Unknown option: $_arg" ;;
	esac
done

[ "$(id -u)" -eq 0 ] || die "Run as root (e.g. ssh root@router && sh install.sh)"

# This project targets GL.iNet hardware + stock firmware only (not generic OpenWrt builds).
require_glinet_router() {
	[ -f /etc/config/glconfig ] && return 0
	[ -f /etc/openwrt_release ] || die "GL.iNet Privacy: /etc/openwrt_release missing — use a GL.iNet router with stock firmware."
	# shellcheck disable=SC1091
	. /etc/openwrt_release
	_m="${DISTRIB_ID:-} ${DISTRIB_DESCRIPTION:-}"
	case "$_m" in
		*[Gg][Ll].[Ii][Nn][Ee][Tt]*) return 0 ;;
		*[Gg][Ll][Ii][Nn][Ee][Tt]*) return 0 ;;
	esac
	die "GL.iNet Privacy: unsupported image — install only on GL.iNet stock firmware (need /etc/config/glconfig or GL.iNet in /etc/openwrt_release)."
}

require_glinet_router

mktemp_dir() {
	if command -v mktemp >/dev/null 2>&1; then
		mktemp -d /tmp/glinet-privacy-install.XXXXXX 2>/dev/null || echo "/tmp/glinet-privacy-install-$$"
	else
		_d="/tmp/glinet-privacy-install-$$"
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
		*install.sh)
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
		command -v git >/dev/null 2>&1 || die "git not found; use GLINET_PRIVACY_TARBALL_URL"
		CLEANUP_DIR="$(mktemp_dir)"
		mkdir -p "$CLEANUP_DIR"
		git clone --depth 1 --branch "$BRANCH" "$GLINET_PRIVACY_GIT_URL" "$CLEANUP_DIR/repo" \
			|| git clone --depth 1 "$GLINET_PRIVACY_GIT_URL" "$CLEANUP_DIR/repo" \
			|| die "git clone failed"
		[ -d "$CLEANUP_DIR/repo/package/glinet-privacy/files" ] \
			|| die "git clone invalid: missing package/glinet-privacy/files"
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
		[ -s "$_tgz" ] || die "Download is empty (check GLINET_PRIVACY_TARBALL_URL)"
		( cd "$CLEANUP_DIR/out" && tar xzf "$_tgz" ) || die "tar extract failed"
		_extracted=""
		for _d in "$CLEANUP_DIR/out"/*; do
			[ -d "$_d" ] || continue
			_extracted="$_d"
			break
		done
		[ -n "$_extracted" ] && [ -d "$_extracted/package/glinet-privacy/files" ] \
			|| die "Archive must contain package/glinet-privacy/files (use a source tree tarball, not a release asset without package/)"
		REPO_ROOT="$_extracted"
		return
	fi

	# Piped from curl|sh: $0 is often "sh" — require explicit URL or SRC
	case "${0##*/}" in
		install.sh) ;;
		*)
			if [ -z "${GLINET_PRIVACY_SRC:-}" ] && [ -z "${GLINET_PRIVACY_TARBALL_URL:-}" ] && [ -z "${GLINET_PRIVACY_GIT_URL:-}" ]; then
				die "When piping the script, set GLINET_PRIVACY_TARBALL_URL=https://github.com/USER/REPO/archive/refs/heads/main.tar.gz (or GLINET_PRIVACY_SRC=/path/to/clone)"
			fi
			;;
	esac

	die "Set GLINET_PRIVACY_SRC, GLINET_PRIVACY_GIT_URL, or GLINET_PRIVACY_TARBALL_URL."
}

cleanup() {
	[ -n "$CLEANUP_DIR" ] && [ -d "$CLEANUP_DIR" ] && rm -rf "$CLEANUP_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# True if opkg reports the package as installed (exact name).
pkg_installed() {
	_p="$1"
	opkg list-installed "$_p" 2>/dev/null | grep -q "^${_p} "
}

# iptables userland: OpenWrt 22+ often has iptables-nft only (no separate iptables-mod-*).
iptables_stack_ok() {
	if pkg_installed iptables-nft; then
		return 0
	fi
	pkg_installed iptables || return 1
	pkg_installed iptables-mod-nat || return 1
	pkg_installed iptables-mod-extra || return 1
	pkg_installed iptables-mod-comment || return 1
	return 0
}

# WireGuard is built-in, loaded, or kmod package already installed — skip kmod-wireguard opkg.
wireguard_kernel_ok() {
	[ -d /sys/module/wireguard ] && return 0
	lsmod 2>/dev/null | grep -q '^wireguard ' && return 0
	pkg_installed kmod-wireguard && return 0
	return 1
}

# Do not use "opkg -V 0 install": some vendor images (e.g. GL.iNet) treat "-V 0" as invalid and print usage instead of installing.
opkg_install_quiet() {
	opkg install "$@" >/dev/null 2>&1 || return 1
	return 0
}

# Install one package if missing; log failures (non-fatal).
opkg_install_one() {
	_pkg="$1"
	pkg_installed "$_pkg" && return 0
	log "opkg: installing $_pkg"
	opkg_install_quiet "$_pkg" || log "opkg install failed (optional): $_pkg"
}

# Install several missing packages in one opkg invocation (less feed reload / duplicate log lines).
opkg_install_missing_from_list() {
	_batch=""
	for _p in "$@"; do
		pkg_installed "$_p" && continue
		if [ -z "$_batch" ]; then
			_batch="$_p"
		else
			_batch="$_batch $_p"
		fi
	done
	[ -n "$_batch" ] || return 0
	log "opkg: installing $_batch"
	opkg_install_quiet $_batch || log "opkg install failed (optional): $_batch"
}

install_opkg_packages() {
	[ "$MINIMAL" -eq 0 ] || return 0
	command -v opkg >/dev/null 2>&1 || { log "opkg not found; skip package installs"; return 0; }

	_needs_install=0
	iptables_stack_ok || _needs_install=1
	for _p in tor ca-bundle wireguard-tools; do
		pkg_installed "$_p" || _needs_install=1
	done
	if ! wireguard_kernel_ok && ! pkg_installed kmod-wireguard; then
		_needs_install=1
	fi
	if ! pkg_installed dnsmasq-full && ! pkg_installed dnsmasq; then
		_needs_install=1
	fi
	if [ "$INSTALL_LUCI" -eq 1 ] && ! pkg_installed luci-lua-runtime; then
		_needs_install=1
	fi

	if [ "$_needs_install" -eq 1 ]; then
		if [ "${GLINET_PRIVACY_SKIP_OPKG_UPDATE:-0}" = "1" ]; then
			log "Skipping opkg update (GLINET_PRIVACY_SKIP_OPKG_UPDATE=1)"
		else
			log "opkg update"
			opkg update || log "opkg update failed (offline? feeds may be stale)"
		fi
	else
		log "opkg: dependencies satisfied; skipping opkg update"
	fi

	if iptables_stack_ok; then
		log "opkg: iptables stack already present (iptables-nft or iptables + modules)"
	else
		opkg_install_missing_from_list iptables iptables-mod-nat iptables-mod-extra iptables-mod-comment
	fi

	opkg_install_missing_from_list tor ca-bundle

	# Optional helper; not in all feeds — do not force opkg update if only this is missing.
	opkg_install_one tor-fw-helper

	opkg_install_one wireguard-tools

	if wireguard_kernel_ok; then
		log "WireGuard kernel support present; skipping kmod-wireguard"
	else
		opkg_install_one kmod-wireguard
	fi

	if pkg_installed dnsmasq-full || pkg_installed dnsmasq; then
		: dnsmasq already present
	else
		opkg_install_one dnsmasq-full
	fi

	if [ "$INSTALL_LUCI" -eq 1 ]; then
		opkg_install_missing_from_list luci-lua-runtime
	fi
}

install_core() {
	_SRC="$REPO_ROOT/package/glinet-privacy/files"
	[ -d "$_SRC" ] || die "Missing $_SRC"
	log "Installing core: $_SRC -> /"
	( cd "$_SRC" && find . -type f ) | while IFS= read -r _r; do
		_r="${_r#./}"
		mkdir -p "/$(dirname "$_r")"
		cp -f "$_SRC/$_r" "/$_r"
	done
}

chmod_installed() {
	_SRC="$REPO_ROOT/package/glinet-privacy/files"
	( cd "$_SRC" && find . -type f ) | while IFS= read -r _r; do
		_r="${_r#./}"
		case "$_r" in
			usr/bin/*|usr/libexec/*|etc/init.d/*|etc/uci-defaults/*|etc/firewall.privacy-tor.sh)
				chmod 755 "/$_r" 2>/dev/null || true
				;;
			*)
				chmod 644 "/$_r" 2>/dev/null || true
				;;
		esac
	done
}

register_firewall() {
	if [ -x /usr/bin/apply-privacy-firewall-includes.sh ]; then
		/usr/bin/apply-privacy-firewall-includes.sh || log "apply-privacy-firewall-includes.sh failed (non-fatal)"
	else
		if ! uci -q get firewall.glinet_privacy >/dev/null 2>&1; then
			uci set firewall.glinet_privacy=include
			uci set firewall.glinet_privacy.path='/usr/libexec/glinet-privacy/fw-plugin.sh'
			uci set firewall.glinet_privacy.reload='1'
			uci set firewall.glinet_privacy.enabled='1'
		fi
		uci -q delete firewall.privacy_tor 2>/dev/null || true
		uci commit firewall
	fi
}

merge_torrc() {
	[ "$MINIMAL" -eq 0 ] || return 0
	mkdir -p /etc/tor/torrc.d
	[ -f /etc/tor/torrc ] || touch /etc/tor/torrc
	if ! grep -qF '99-transparent.conf' /etc/tor/torrc 2>/dev/null; then
		log "Appending Tor include for transparent proxy"
		printf '\n# glinet-privacy\n%%include /etc/tor/torrc.d/99-transparent.conf\n' >> /etc/tor/torrc
	fi
}

enable_tor() {
	[ "$MINIMAL" -eq 0 ] || return 0
	[ -x /etc/init.d/tor ] || { log "Tor init script missing; install package tor"; return 0; }
	/etc/init.d/tor enable 2>/dev/null || true
	/etc/init.d/tor restart 2>/dev/null || /etc/init.d/tor start 2>/dev/null || true
}

enable_killswitch_init() {
	[ "$MINIMAL" -eq 0 ] || return 0
	[ -x /etc/init.d/privacy-killswitch ] || return 0
	/etc/init.d/privacy-killswitch enable 2>/dev/null || true
	/etc/init.d/privacy-killswitch start 2>/dev/null || true
}

crontab_ensure_line() {
	_line="$1"
	_cr="/etc/crontabs/root"
	mkdir -p /etc/crontabs
	[ -f "$_cr" ] || touch "$_cr"
	if ! grep -qF "$_line" "$_cr" 2>/dev/null; then
		printf '%s\n' "$_line" >> "$_cr"
		log "Added crontab line: $_line"
	fi
}

setup_cron() {
	[ "$MINIMAL" -eq 0 ] || return 0
	[ -x /etc/init.d/cron ] || { log "cron not installed; skip crontab"; return 0; }
	crontab_ensure_line "*/1 * * * * /usr/bin/privacy-killswitch-watchdog.sh"
	if [ "$IMEI_CRON" -eq 1 ] && [ -f /etc/config/rotate_imei ]; then
		uci set rotate_imei.main.cron_enabled='1'
		uci set rotate_imei.main.cron_interval_hours='6'
		uci commit rotate_imei
	fi
	if [ -x /usr/libexec/glinet-privacy/apply-rotate-imei-cron.sh ]; then
		/usr/libexec/glinet-privacy/apply-rotate-imei-cron.sh || true
	fi
	/etc/init.d/cron enable 2>/dev/null || true
	/etc/init.d/cron restart 2>/dev/null || true
}

setup_telemetry() {
	[ "$MINIMAL" -eq 0 ] || return 0
	[ -f /etc/config/glinet_privacy ] || return 0
	# Seed blocklist + vendor-cloud defaults once (safe re-runs; override with GLINET_PRIVACY_FORCE_TELEMETRY_SEED=1)
	if [ "${GLINET_PRIVACY_FORCE_TELEMETRY_SEED:-0}" = "1" ] || [ ! -f /etc/glinet-privacy/.telemetry-seeded ]; then
		mkdir -p /etc/glinet-privacy 2>/dev/null || true
		uci set glinet_privacy.tel.block_domains='1' 2>/dev/null || true
		uci set glinet_privacy.tel.disable_vendor_cloud='1' 2>/dev/null || true
		uci commit glinet_privacy 2>/dev/null || true
		touch /etc/glinet-privacy/.telemetry-seeded 2>/dev/null || true
		log "Telemetry defaults applied (first run or forced); marker: /etc/glinet-privacy/.telemetry-seeded"
	fi
	# GL.iNet images may omit /etc/dnsmasq.d; apply-telemetry.sh also mkdir -p, belt-and-suspenders for stock layouts
	mkdir -p /etc/dnsmasq.d 2>/dev/null || true
	if [ -x /usr/libexec/glinet-privacy/apply-telemetry.sh ]; then
		/usr/libexec/glinet-privacy/apply-telemetry.sh || true
	fi
	# dnsmasq reads /etc/dnsmasq.d when confdir lists it (idempotent: no duplicate list entries)
	if uci -q get dhcp.@dnsmasq[0] >/dev/null 2>&1; then
		if uci show dhcp.@dnsmasq[0] 2>/dev/null | grep -qF "/etc/dnsmasq.d"; then
			: already has confdir for dnsmasq.d
		else
			uci add_list dhcp.@dnsmasq[0].confdir='/etc/dnsmasq.d' 2>/dev/null \
				|| uci set dhcp.@dnsmasq[0].confdir='/etc/dnsmasq.d' 2>/dev/null || true
			uci commit dhcp 2>/dev/null || true
			log "dhcp: set dnsmasq confdir /etc/dnsmasq.d"
		fi
	fi
}

setup_dns_policy() {
	[ "$MINIMAL" -eq 0 ] || return 0
	[ -x /usr/libexec/glinet-privacy/apply-dns-policy.sh ] || return 0
	/usr/libexec/glinet-privacy/apply-dns-policy.sh || true
}

# Merge vendor_ubus UCI for upgrades (LuCI reads it; default off — docs/vendor-ubus.md)
ensure_glinet_privacy_vendor_ubus() {
	[ -f /etc/config/glinet_privacy ] || return 0
	if ! uci -q show glinet_privacy.vendor_ubus >/dev/null 2>&1; then
		uci set glinet_privacy.vendor_ubus=vendor_ubus
		uci set glinet_privacy.vendor_ubus.enabled='0'
		uci set glinet_privacy.vendor_ubus.min_release_substr=''
		uci commit glinet_privacy 2>/dev/null || true
		log "glinet_privacy.vendor_ubus added (default off); see docs/vendor-ubus.md"
	fi
}

setup_imei_boot() {
	[ "$IMEI_BOOT" -eq 1 ] || return 0
	[ -f /etc/config/rotate_imei ] || return 0
	uci set rotate_imei.main.enabled='1'
	uci commit rotate_imei
	[ -x /etc/init.d/rotate_imei ] || return 0
	/etc/init.d/rotate_imei enable 2>/dev/null || true
	/etc/init.d/rotate_imei start 2>/dev/null || true
	log "IMEI rotation enabled on boot — read docs/devices.md (IMEI legal use); compliance is your responsibility"
}

install_file() {
	_src="$1"
	_dst="$2"
	_mode="$3"
	mkdir -p "$(dirname "$_dst")"
	cp -f "$_src" "$_dst"
	chmod "$_mode" "$_dst"
}

# LuCI Lua controllers require luci-lua-runtime on ucode-first LuCI (GL.iNet 4.x). Hard prerequisite when LuCI is installed.
require_luci_lua_runtime_for_luci() {
	[ "$INSTALL_LUCI" -eq 1 ] || return 0
	pkg_installed luci-lua-runtime && return 0
	command -v opkg >/dev/null 2>&1 || die "LuCI install requires opkg package luci-lua-runtime; opkg not found. Use --without-luci or install luci-lua-runtime manually."
	if [ "${GLINET_PRIVACY_SKIP_OPKG_UPDATE:-0}" != "1" ]; then
		opkg update || true
	fi
	log "opkg: installing luci-lua-runtime (required for LuCI Lua controllers)"
	opkg_install_quiet luci-lua-runtime || true
	pkg_installed luci-lua-runtime || die "Could not install luci-lua-runtime (required for this LuCI app). Online router: opkg update && opkg install luci-lua-runtime. Or: sh install.sh --without-luci"
}

# LuCI: default Lua index() (vendor-style). Optional menu.d JSON + marker when GLINET_PRIVACY_LUCI_MENU_JSON=1.
install_luci_menu_json() {
	_LUCI="$REPO_ROOT/package/luci-app-glinet-privacy"
	_json="$_LUCI/root/usr/share/luci/menu.d/luci-app-glinet-privacy.json"
	[ -f "$_json" ] || return 0

	if [ "${GLINET_PRIVACY_LUCI_MENU_JSON:-auto}" = "1" ]; then
		mkdir -p /usr/share/luci/menu.d
		install_file "$_json" /usr/share/luci/menu.d/luci-app-glinet-privacy.json 0644
		mkdir -p /usr/share/glinet-privacy
		: > /usr/share/glinet-privacy/luci-use-menu-d
		log "LuCI menu.d installed; Lua controller index() skipped. Clear /tmp/luci-indexcache* if menu is stale."
		return 0
	fi

	rm -f /usr/share/luci/menu.d/luci-app-glinet-privacy.json 2>/dev/null || true
	rm -f /usr/share/glinet-privacy/luci-use-menu-d 2>/dev/null || true
	if [ "${GLINET_PRIVACY_LUCI_MENU_JSON:-auto}" = "0" ]; then
		log "LuCI menu.d: skipped (GLINET_PRIVACY_LUCI_MENU_JSON=0)"
	else
		log "LuCI menu.d: skipped (default Lua index(); GLINET_PRIVACY_LUCI_MENU_JSON=1 for JSON menu)"
	fi
}

install_luci() {
	_LUCI="$REPO_ROOT/package/luci-app-glinet-privacy"
	[ -d "$_LUCI/luasrc" ] || { log "LuCI sources missing; skip"; return 0; }
	require_luci_lua_runtime_for_luci
	log "Installing LuCI: $_LUCI"
	mkdir -p /usr/lib/lua/luci/controller
	install_file "$_LUCI/luasrc/controller/glinet_privacy.lua" /usr/lib/lua/luci/controller/glinet_privacy.lua 0644
	if [ -f "$_LUCI/luasrc/glinet_privacy/i18n.lua" ]; then
		mkdir -p /usr/lib/lua/luci/glinet_privacy
		install_file "$_LUCI/luasrc/glinet_privacy/i18n.lua" \
			/usr/lib/lua/luci/glinet_privacy/i18n.lua 0644
	fi
	if [ -f "$_LUCI/luasrc/glinet_privacy/imei_detect.lua" ]; then
		install_file "$_LUCI/luasrc/glinet_privacy/imei_detect.lua" \
			/usr/lib/lua/luci/glinet_privacy/imei_detect.lua 0644
	fi
	if [ -f "$_LUCI/luasrc/glinet_privacy/net_probe.lua" ]; then
		install_file "$_LUCI/luasrc/glinet_privacy/net_probe.lua" \
			/usr/lib/lua/luci/glinet_privacy/net_probe.lua 0644
	fi
	if [ -f "$_LUCI/luasrc/glinet_privacy/firewall_status.lua" ]; then
		install_file "$_LUCI/luasrc/glinet_privacy/firewall_status.lua" \
			/usr/lib/lua/luci/glinet_privacy/firewall_status.lua 0644
	fi
	if [ -f "$_LUCI/luasrc/glinet_privacy/privacy_log_excerpt.lua" ]; then
		install_file "$_LUCI/luasrc/glinet_privacy/privacy_log_excerpt.lua" \
			/usr/lib/lua/luci/glinet_privacy/privacy_log_excerpt.lua 0644
	fi
	if [ -f "$_LUCI/luasrc/glinet_privacy/sanitize.lua" ]; then
		install_file "$_LUCI/luasrc/glinet_privacy/sanitize.lua" \
			/usr/lib/lua/luci/glinet_privacy/sanitize.lua 0644
	fi
	if [ -f "$_LUCI/luasrc/glinet_privacy/csrf.lua" ]; then
		install_file "$_LUCI/luasrc/glinet_privacy/csrf.lua" \
			/usr/lib/lua/luci/glinet_privacy/csrf.lua 0644
	fi
	if [ -f "$_LUCI/luasrc/glinet_privacy/vpn_probe.lua" ]; then
		install_file "$_LUCI/luasrc/glinet_privacy/vpn_probe.lua" \
			/usr/lib/lua/luci/glinet_privacy/vpn_probe.lua 0644
	fi
	if [ -f "$_LUCI/luasrc/glinet_privacy/vendor_ubus.lua" ]; then
		install_file "$_LUCI/luasrc/glinet_privacy/vendor_ubus.lua" \
			/usr/lib/lua/luci/glinet_privacy/vendor_ubus.lua 0644
	fi
	mkdir -p /usr/lib/lua/luci/view/glinet_privacy
	for _v in overview.htm verify.htm killswitch.htm imei.htm tor_dns.htm vendor_ubus_card.htm csrf_field.htm; do
		[ -f "$_LUCI/luasrc/view/glinet_privacy/$_v" ] || continue
		install_file "$_LUCI/luasrc/view/glinet_privacy/$_v" \
			"/usr/lib/lua/luci/view/glinet_privacy/$_v" 0644
	done
	if [ -f "$_LUCI/root/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json" ]; then
		mkdir -p /usr/share/rpcd/acl.d
		install_file "$_LUCI/root/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json" \
			/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json 0644
	fi
	install_luci_i18n_lmo "$_LUCI"
	install_luci_menu_json
}

# Standard LuCI .lmo catalogs (same domain as luci.i18n.loadc("glinet_privacy")).
install_luci_i18n_lmo() {
	_LUCI="$1"
	if ! command -v po2lmo >/dev/null 2>&1; then
		log "po2lmo not found — skipping .lmo (English from Lua sources; use opkg ipk or SDK for translations)"
		return 0
	fi
	for _po in "$_LUCI/po"/*/glinet_privacy.po; do
		[ -f "$_po" ] || continue
		_lang="$(basename "$(dirname "$_po")")"
		mkdir -p /usr/lib/lua/luci/i18n
		if po2lmo "$_po" "/usr/lib/lua/luci/i18n/glinet_privacy.${_lang}.lmo" 2>/dev/null; then
			chmod 644 "/usr/lib/lua/luci/i18n/glinet_privacy.${_lang}.lmo" 2>/dev/null || true
			log "Installed i18n: glinet_privacy.${_lang}.lmo"
		else
			log "po2lmo failed for $_lang (non-fatal)"
		fi
	done
}

restart_services() {
	/etc/init.d/network reload 2>/dev/null || true
	/etc/init.d/firewall reload 2>/dev/null || true
	/etc/init.d/dnsmasq restart 2>/dev/null || true
	/etc/init.d/rpcd restart 2>/dev/null || true
	/etc/init.d/uhttpd restart 2>/dev/null || true
}

resolve_source
log "Using repo root: $REPO_ROOT"
if [ -f "$REPO_ROOT/package/version.mk" ]; then
	_ver="$(grep '^GLINET_PRIVACY_VERSION:=' "$REPO_ROOT/package/version.mk" | head -1 | sed 's/^GLINET_PRIVACY_VERSION:=//')"
	_rel="$(grep '^GLINET_PRIVACY_RELEASE:=' "$REPO_ROOT/package/version.mk" | head -1 | sed 's/^GLINET_PRIVACY_RELEASE:=//')"
	if [ -n "$_ver" ] && [ -n "$_rel" ]; then
		log "Package version (source): ${_ver}-r${_rel}"
	elif [ -n "$_ver" ]; then
		log "Package version (source): ${_ver}"
	fi
fi

install_opkg_packages
install_core
chmod_installed
register_firewall

if [ -x /usr/libexec/glinet-privacy/apply-device-profile.sh ]; then
	/usr/libexec/glinet-privacy/apply-device-profile.sh || log "apply-device-profile (non-fatal)"
fi

merge_torrc
enable_tor
enable_killswitch_init
setup_cron
setup_telemetry
ensure_glinet_privacy_vendor_ubus
setup_imei_boot
setup_dns_policy

if [ "$INSTALL_LUCI" -eq 1 ]; then
	install_luci
fi

restart_services

if [ -f /usr/share/glinet-privacy/version.mk ]; then
	_ver="$(grep '^GLINET_PRIVACY_VERSION:=' /usr/share/glinet-privacy/version.mk | head -1 | sed 's/^GLINET_PRIVACY_VERSION:=//')"
	[ -n "$_ver" ] && log "Installed package version: $_ver"
fi
log "Done. LuCI: Services → GL.iNet Privacy (skipped if --without-luci). --minimal skips Tor/opkg/cron/telemetry automation."
