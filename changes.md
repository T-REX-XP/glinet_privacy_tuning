# Changelog

Version numbers follow **semantic versioning** (`MAJOR.MINOR.PATCH`).  
**Source of truth:** `package/version.mk` (`GLINET_PRIVACY_VERSION`, `GLINET_PRIVACY_RELEASE`).

Both **`glinet-privacy`** and **`luci-app-glinet-privacy`** use the same `PKG_VERSION` / `PKG_RELEASE` from that file.

## Release process (each change request)

1. Edit **`package/version.mk`**
   - Bump **`GLINET_PRIVACY_VERSION`** for functional or documentation-visible changes (patch or minor as appropriate).
   - Bump **`GLINET_PRIVACY_RELEASE`** only when rebuilding the **same** version (e.g. packaging fix, no version bump).
2. Append an entry under the new version in **`changes.md`** (this file).
3. Rebuild ipk packages if you ship binaries.

---

## 1.1.9 (2026-04-08)

### Added

- **README.md** — project overview, install and SDK pointers, link to [github.com/T-REX-XP/glinet_privacy_tuning](https://github.com/T-REX-XP/glinet_privacy_tuning).

### Changed

- **CI** (`.github/workflows/openwrt-packages.yml`): `concurrency.cancel-in-progress` only for **`pull_request`** (branch/tag pushes no longer abort in-flight SDK jobs); `actions/checkout@v6`, `actions/upload-artifact@v6` (Node.js 24–compatible actions per GitHub guidance).

---

## 1.1.8 (2026-04-08)

### Added

- **LuCI i18n**: `package/luci-app-glinet-privacy/po/` — `templates/glinet_privacy.pot`, catalogs `en` / `uk` / `de` (`glinet_privacy.po`). Host scripts `tools/extract-luci-i18n-strings.py` and `tools/i18n-build-po-from-pot.py` regenerate POT/PO from LuCI sources. The app Makefile runs `po2lmo` (`PKG_BUILD_DEPENDS:=luci-base/host`) and installs `glinet_privacy.<lang>.lmo` under `/usr/lib/lua/luci/i18n/`. Runtime catalog load via `luasrc/glinet_privacy/i18n.lua` (`luci.glinet_privacy.i18n`).

---

## 1.1.7 (2026-04-08)

### Added

- **Task 3.1 — GL.iNet vendor VPN kill switch**: UCI **`privacy.main.vendor_gl_vpn_killswitch`** (`leave` / `on` / `off`), script **`apply-vendor-vpn-killswitch.sh`** (sets **`glvpn.general.block_non_vpn`** when **`/etc/config/glvpn`** exists), LuCI **Kill switch** option, **`docs/devices.md`** coexistence notes. **rpcd** ACL extended with **`glvpn`**.

---

## 1.1.6 (2026-04-08)

### Added

- **DNS leak reduction (Task 2.4)**: UCI **`glinet_privacy.dns`** — **`dns_policy`** (`default` / `tor_dnsmasq` / `mullvad_dnsmasq`), **`mullvad_dns`**, **`redirect_tcp_dns`**, **`block_lan_dot`**; **`/usr/libexec/glinet-privacy/apply-dns-policy.sh`** configures **dnsmasq** to use **127.0.0.1#DNSPort** (Tor) or Mullvad DNS with **`noresolv=1`**. **`firewall.privacy-tor.sh`** redirects **LAN TCP/53** to Tor DNSPort (optional) and optional **FORWARD DROP** for **TCP/853** (DoT). LuCI **Tor, DNS & telemetry**; **`apply-mullvad-wireguard.sh`** syncs **`mullvad_dnsmasq`** when **`/etc/config/glinet_privacy`** exists. **`install.sh`**: **`setup_dns_policy`**.

---

## 1.1.5 (2026-04-08)

### Added

- **IMEI legal documentation**: expanded **`docs/devices.md`** (jurisdiction, operator/lab-only framing, responsibility); **`rotate_imei.sh`** header + per-run syslog notice (`legal_notice()`); optional **`ROTATE_IMEI_SUPPRESS_LEGAL_LOG=1`** for cron after compliance review. LuCI IMEI page, UCI/init/crontab examples, and **`install.sh`** help text updated accordingly.

---

## 1.1.4 (2026-04-08)

### Added

- **Telemetry / GoodCloud**: `disable-glinet-telemetry.sh` now applies **`glconfig.cloud.enable=0`** (stock GL.iNet reference), keeps other UCI toggles, stops **`gl_cloud`** / related init scripts, and optionally **`opkg remove`** **`gl-cloud`** (and similar) when **`glinet_privacy.tel.remove_cloud_packages=1`**.
- **`apply-telemetry.sh`**: installs **`/etc/dnsmasq.d/glinet-block.conf`** when either **blocklist** or **disable vendor cloud** is enabled (DNS black-hole for goodcloud.xyz, gldns.com, etc. — avoids appending to `/etc/dnsmasq.conf`).

### Changed

- **`install.sh`**: default telemetry path sets **`disable_vendor_cloud=1`** and uses **`apply-telemetry.sh`** only (no duplicate unconditional disable script).

---

## 1.1.3 (2026-04-08)

### Added

- **LuCI Overview** (`Services → GL.iNet Privacy`): onboarding-style checklist (ok / problem / skipped), progress bar, and quick toggles for kill switch, WireGuard/Tor requirements, Tor transparent NAT, telemetry blocklist, vendor script, and IMEI rotation when `rotate_imei` UCI exists.

### Changed

- **CI** (`.github/workflows/openwrt-packages.yml`): SDK matrix uses **`mipsel_24kc`** (e.g. GL-XE300 Puli) and **`aarch64_cortex-a53`** (e.g. GL-AXT1800 Slate AX, GL-AX1800 Flint) instead of **`x86_64`**.

---

## 1.1.2 (2026-04-08)

### Changed

- **`install.sh`**: default run now automates **`openwrt/INSTALL.txt`** steps — opkg packages (WireGuard, Tor, dnsmasq-full, etc.), Tor **`torrc`** merge + enable, killswitch **init** + **cron** watchdog, telemetry blocklist + **dnsmasq** **confdir**, optional **Mullvad** when **`MULLVAD_*`** env vars are set. Use **`--minimal`** for file-only install; **`--with-imei-boot`** / **`--with-imei-cron`** for cellular IMEI options.
- **`openwrt/INSTALL.txt`**: rewritten around **`install.sh`** as the primary procedure.

---

## 1.1.1 (2026-04-08)

### Added

- **GitHub Actions** workflow **`.github/workflows/openwrt-packages.yml`**: builds **`glinet-privacy`** and **`luci-app-glinet-privacy`** with **`openwrt/gh-action-sdk`**, uploads **`.ipk`** as workflow artifacts, and attaches them to a **GitHub Release** on **`v*`** tag pushes.

---

## 1.1.0 (2026-04-08)

### Added

- Centralized versioning in **`package/version.mk`** (shared by both OpenWrt packages).
- **`changes.md`** for incremental release notes and change-request tracking.

### Changed

- **`glinet-privacy`** and **`luci-app-glinet-privacy`** Makefiles now include **`version.mk`** instead of hardcoded versions.

---

## 1.0.0 (initial)

### Added

- Core: kill switch watchdog, IMEI rotation, Mullvad helper, Tor NAT firewall plugin, telemetry helpers.
- OpenWrt packages **`glinet-privacy`** and **`luci-app-glinet-privacy`**.
- **`install.sh`** one-shot installer; device profiles (GL-XE300 Puli, GL-AXT1800 Slate AX, etc.).
- Documentation under **`docs/`**.
