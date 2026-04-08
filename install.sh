#!/bin/sh
# glinet_puli_privacy — one-shot installer for OpenWrt / GL.iNet (POSIX sh).
#
# Default: copies package files, registers firewall, applies device profile, installs
# optional opkg packages, merges Tor config, enables services, cron watchdog, telemetry.
#
#   sh install.sh
#   sh install.sh --with-luci
#   sh install.sh --minimal
#
# curl | sh:
#   curl -fsSL ... | GLINET_PRIVACY_TARBALL_URL=... sh -s -- --with-luci
#
# Optional flags:
#   --minimal          Only copy files + firewall + device profile (no opkg/Tor/cron/telemetry)
#   --with-luci        Install LuCI app files
#   --with-imei-boot   Enable rotate_imei on boot (uci + init.d)
#   --with-imei-cron    Add crontab: IMEI rotate every 6 hours
#
# Mullvad (optional): export MULLVAD_PRIVATE_KEY MULLVAD_ADDRESS MULLVAD_PUBLIC_KEY MULLVAD_ENDPOINT
#   then run install.sh — apply-mullvad-wireguard.sh runs if all are set.
#
# Env: GLINET_PRIVACY_SRC, GLINET_PRIVACY_GIT_URL, GLINET_PRIVACY_TARBALL_URL,
#      GLINET_PRIVACY_BRANCH (default main)
#
# Package version: package/version.mk

set -eu

BRANCH="${GLINET_PRIVACY_BRANCH:-main}"
INSTALL_LUCI=0
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

  sh install.sh [--with-luci] [--minimal] [--with-imei-boot] [--with-imei-cron]

Default install applies: opkg deps (if available), Tor torrc merge, killswitch cron,
telemetry blocklist + dnsmasq confdir, init.d services.

  --minimal           Skip opkg/Tor/cron/telemetry automation (files + firewall only)
  --with-luci         Install LuCI UI files
  --with-imei-boot    Enable IMEI rotation on boot (cellular routers; legal risk — see docs/devices.md)
  --with-imei-cron    Add cron every 6h for rotate_imei.sh (same; optional ROTATE_IMEI_SUPPRESS_LEGAL_LOG=1 in crontab)

Remote: GLINET_PRIVACY_TARBALL_URL=... or GLINET_PRIVACY_GIT_URL=...

Mullvad: export MULLVAD_PRIVATE_KEY MULLVAD_ADDRESS MULLVAD_PUBLIC_KEY MULLVAD_ENDPOINT
EOF
}

for _arg in "$@"; do
	case "$_arg" in
		--with-luci) INSTALL_LUCI=1 ;;
		--minimal) MINIMAL=1 ;;
		--with-imei-boot) IMEI_BOOT=1 ;;
		--with-imei-cron) IMEI_CRON=1 ;;
		-h|--help) print_help; exit 0 ;;
		*) die "Unknown option: $_arg" ;;
	esac
done

[ "$(id -u)" -eq 0 ] || die "Run as root (e.g. ssh root@router && sh install.sh)"

[ -f /etc/openwrt_release ] || log "Warning: /etc/openwrt_release not found — not OpenWrt?"

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
		_extracted=""
		for _d in "$CLEANUP_DIR/out"/*; do
			[ -d "$_d" ] || continue
			_extracted="$_d"
			break
		done
		[ -n "$_extracted" ] && [ -d "$_extracted/package/glinet-privacy/files" ] \
			|| die "Archive must contain package/glinet-privacy/files"
		REPO_ROOT="$_extracted"
		return
	fi

	die "Set GLINET_PRIVACY_SRC, GLINET_PRIVACY_GIT_URL, or GLINET_PRIVACY_TARBALL_URL."
}

cleanup() {
	[ -n "$CLEANUP_DIR" ] && [ -d "$CLEANUP_DIR" ] && rm -rf "$CLEANUP_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

install_opkg_packages() {
	[ "$MINIMAL" -eq 0 ] || return 0
	command -v opkg >/dev/null 2>&1 || { log "opkg not found; skip package installs"; return 0; }
	log "opkg update"
	opkg update || log "opkg update failed (offline?)"
	_pkgs="iptables iptables-mod-nat iptables-mod-extra iptables-mod-comment wireguard-tools kmod-wireguard tor tor-fw-helper dnsmasq-full ca-bundle"
	for _p in $_pkgs; do
		opkg install -V 0 "$_p" 2>/dev/null || log "Optional package not installed: $_p"
	done
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
	if ! uci -q get firewall.glinet_privacy >/dev/null 2>&1; then
		uci set firewall.glinet_privacy=include
		uci set firewall.glinet_privacy.path='/usr/libexec/glinet-privacy/fw-plugin.sh'
		uci set firewall.glinet_privacy.reload='1'
		uci set firewall.glinet_privacy.enabled='1'
	fi
	uci -q delete firewall.privacy_tor 2>/dev/null || true
	uci commit firewall
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
	if [ "$IMEI_CRON" -eq 1 ]; then
		crontab_ensure_line "0 */6 * * * /usr/bin/rotate_imei.sh"
	fi
	/etc/init.d/cron enable 2>/dev/null || true
	/etc/init.d/cron restart 2>/dev/null || true
}

setup_telemetry() {
	[ "$MINIMAL" -eq 0 ] || return 0
	[ -f /etc/config/glinet_privacy ] || return 0
	uci set glinet_privacy.tel.block_domains='1' 2>/dev/null || true
	uci set glinet_privacy.tel.disable_vendor_cloud='1' 2>/dev/null || true
	uci commit glinet_privacy 2>/dev/null || true
	if [ -x /usr/libexec/glinet-privacy/apply-telemetry.sh ]; then
		/usr/libexec/glinet-privacy/apply-telemetry.sh || true
	fi
	# dnsmasq reads /etc/dnsmasq.d when confdir lists it
	if uci -q get dhcp.@dnsmasq[0] >/dev/null 2>&1; then
		if ! uci show dhcp 2>/dev/null | grep -q "confdir.*dnsmasq.d"; then
			uci add_list dhcp.@dnsmasq[0].confdir='/etc/dnsmasq.d' 2>/dev/null \
				|| uci set dhcp.@dnsmasq[0].confdir='/etc/dnsmasq.d' 2>/dev/null || true
		fi
		uci commit dhcp 2>/dev/null || true
	fi
}

setup_dns_policy() {
	[ "$MINIMAL" -eq 0 ] || return 0
	[ -x /usr/libexec/glinet-privacy/apply-dns-policy.sh ] || return 0
	/usr/libexec/glinet-privacy/apply-dns-policy.sh || true
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

maybe_mullvad() {
	[ "$MINIMAL" -eq 0 ] || return 0
	_have_ep=0
	[ -n "${MULLVAD_ENDPOINT:-}" ] && _have_ep=1
	[ -n "${MULLVAD_ENDPOINT_HOST:-}" ] && _have_ep=1
	[ -n "${MULLVAD_PRIVATE_KEY:-}" ] && [ -n "${MULLVAD_ADDRESS:-}" ] \
		&& [ -n "${MULLVAD_PUBLIC_KEY:-}" ] && [ "$_have_ep" -eq 1 ] || {
		log "Mullvad: set MULLVAD_PRIVATE_KEY, ADDRESS, PUBLIC_KEY, and ENDPOINT (or ENDPOINT_HOST+PORT)"
		return 0
	}
	log "Applying Mullvad WireGuard (env credentials set)"
	/usr/bin/apply-mullvad-wireguard.sh || log "apply-mullvad-wireguard.sh failed"
	/etc/init.d/network reload 2>/dev/null || true
}

install_file() {
	_src="$1"
	_dst="$2"
	_mode="$3"
	mkdir -p "$(dirname "$_dst")"
	cp -f "$_src" "$_dst"
	chmod "$_mode" "$_dst"
}

install_luci() {
	_LUCI="$REPO_ROOT/package/luci-app-glinet-privacy"
	[ -d "$_LUCI/luasrc" ] || { log "LuCI sources missing; skip"; return 0; }
	log "Installing LuCI: $_LUCI"
	mkdir -p /usr/lib/lua/luci/controller
	install_file "$_LUCI/luasrc/controller/glinet_privacy.lua" /usr/lib/lua/luci/controller/glinet_privacy.lua 0644
	mkdir -p /usr/lib/lua/luci/model/cbi/glinet_privacy
	for _f in killswitch.lua imei.lua plugins.lua; do
		[ -f "$_LUCI/luasrc/model/cbi/glinet_privacy/$_f" ] || continue
		install_file "$_LUCI/luasrc/model/cbi/glinet_privacy/$_f" \
			"/usr/lib/lua/luci/model/cbi/glinet_privacy/$_f" 0644
	done
	mkdir -p /usr/lib/lua/luci/view/glinet_privacy
	for _v in overview.htm wireguard.htm; do
		[ -f "$_LUCI/luasrc/view/glinet_privacy/$_v" ] || continue
		install_file "$_LUCI/luasrc/view/glinet_privacy/$_v" \
			"/usr/lib/lua/luci/view/glinet_privacy/$_v" 0644
	done
	if [ -f "$_LUCI/root/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json" ]; then
		mkdir -p /usr/share/rpcd/acl.d
		install_file "$_LUCI/root/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json" \
			/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json 0644
	fi
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
setup_imei_boot
maybe_mullvad
setup_dns_policy

if [ "$INSTALL_LUCI" -eq 1 ]; then
	install_luci
fi

restart_services

if [ -f /usr/share/glinet-privacy/version.mk ]; then
	_ver="$(grep '^GLINET_PRIVACY_VERSION:=' /usr/share/glinet-privacy/version.mk | head -1 | sed 's/^GLINET_PRIVACY_VERSION:=//')"
	[ -n "$_ver" ] && log "Installed package version: $_ver"
fi
log "Done. LuCI: Services → GL.iNet Privacy (use --with-luci). --minimal skips Tor/opkg/cron/telemetry automation."
