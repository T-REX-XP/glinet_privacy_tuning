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
