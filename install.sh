#!/bin/sh
# glinet_puli_privacy — one-shot installer for OpenWrt / GL.iNet (POSIX sh).
#
# From clone on the router:
#   sh install.sh
#   sh install.sh --with-luci --with-opkg-deps
#
# curl | sh (set your repo URL):
#   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | \
#     GLINET_PRIVACY_TARBALL_URL=https://github.com/USER/REPO/archive/refs/heads/main.tar.gz sh
#
# Or with git (if installed):
#   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | \
#     GLINET_PRIVACY_GIT_URL=https://github.com/USER/REPO.git sh
#
# Env: GLINET_PRIVACY_SRC, GLINET_PRIVACY_GIT_URL, GLINET_PRIVACY_TARBALL_URL,
#      GLINET_PRIVACY_BRANCH (default main)
#
# Package version: package/version.mk (GLINET_PRIVACY_VERSION)

set -eu

BRANCH="${GLINET_PRIVACY_BRANCH:-main}"
INSTALL_LUCI=0
OPKG_DEPS=0
CLEANUP_DIR=""
REPO_ROOT=""

log() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

print_help() {
	cat <<'EOF'
glinet_puli_privacy install.sh

  sh install.sh [--with-luci] [--with-opkg-deps]

Env for remote install:
  GLINET_PRIVACY_TARBALL_URL   e.g. https://github.com/USER/REPO/archive/refs/heads/main.tar.gz
  GLINET_PRIVACY_GIT_URL       e.g. https://github.com/USER/REPO.git
  GLINET_PRIVACY_SRC           path to repo root (no download)
EOF
}

for _arg in "$@"; do
	case "$_arg" in
		--with-luci) INSTALL_LUCI=1 ;;
		--with-opkg-deps) OPKG_DEPS=1 ;;
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

	die "Set GLINET_PRIVACY_SRC, GLINET_PRIVACY_GIT_URL, or GLINET_PRIVACY_TARBALL_URL.
Example:
  curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | \\
    GLINET_PRIVACY_TARBALL_URL=https://github.com/USER/REPO/archive/refs/heads/main.tar.gz sh"
}

cleanup() {
	[ -n "$CLEANUP_DIR" ] && [ -d "$CLEANUP_DIR" ] && rm -rf "$CLEANUP_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

install_opkg_deps() {
	[ "$OPKG_DEPS" -eq 1 ] || return 0
	command -v opkg >/dev/null 2>&1 || { log "opkg not found; skip deps"; return 0; }
	opkg update || log "opkg update failed (offline?)"
	opkg install -V 0 iptables iptables-mod-nat iptables-mod-extra iptables-mod-comment 2>/dev/null \
		|| log "Install iptables + iptables-mod-* manually if needed"
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
	install_file "$_LUCI/luasrc/view/glinet_privacy/wireguard.htm" \
		/usr/lib/lua/luci/view/glinet_privacy/wireguard.htm 0644
	if [ -f "$_LUCI/root/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json" ]; then
		mkdir -p /usr/share/rpcd/acl.d
		install_file "$_LUCI/root/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json" \
			/usr/share/rpcd/acl.d/luci-app-glinet-privacy.json 0644
	fi
}

restart_services() {
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

install_opkg_deps
install_core
chmod_installed
register_firewall

if [ -x /usr/libexec/glinet-privacy/apply-device-profile.sh ]; then
	/usr/libexec/glinet-privacy/apply-device-profile.sh || log "apply-device-profile.sh returned non-zero (ok if UCI missing)"
fi

if [ "$INSTALL_LUCI" -eq 1 ]; then
	install_luci
fi

restart_services

if [ -f /usr/share/glinet-privacy/version.mk ]; then
	_ver="$(grep '^GLINET_PRIVACY_VERSION:=' /usr/share/glinet-privacy/version.mk | head -1 | sed 's/^GLINET_PRIVACY_VERSION:=//')"
	[ -n "$_ver" ] && log "Installed package version: $_ver"
fi
log "Done. LuCI: Services → GL.iNet Privacy (with --with-luci). Firewall: firewall.glinet_privacy"
