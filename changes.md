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
