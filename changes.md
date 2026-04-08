# Changelog

Version numbers follow **semantic versioning** (`MAJOR.MINOR.PATCH`).  
**Source of truth:** `package/version.mk` (`GLINET_PRIVACY_VERSION`, `GLINET_PRIVACY_RELEASE`).

**`install.sh`** logs the version from that file; release notes live in this changelog.

## Release process (each change request)

1. Edit **`package/version.mk`**
   - Bump **`GLINET_PRIVACY_VERSION`** for functional or documentation-visible changes (patch or minor as appropriate).
   - Bump **`GLINET_PRIVACY_RELEASE`** only when you need another release of the **same** version string (rare).
2. Append an entry under the new version in **`changes.md`** (this file).

---

## 1.2.4 (2026-04-08)

### Added

- **IMEI cron from LuCI** — UCI **`rotate_imei.main`**: **`cron_enabled`**, **`cron_interval_hours`** (1–24), **`cron_suppress_legal_log`**. **`usr/libexec/glinet-privacy/apply-rotate-imei-cron.sh`** syncs **`/etc/crontabs/root`**; **`install.sh --with-imei-cron`** seeds **`cron_enabled=1`** and **`cron_interval_hours=6`**. **`README.md`** / **`openwrt/INSTALL.txt`** / crontab example updated.

---

## 1.2.3 (2026-04-08)

### Changed

- **`install.sh`** — Installs LuCI app files **by default** (`INSTALL_LUCI=1`). New **`--without-luci`** skips them; **`--with-luci`** remains as a no-op compatibility alias. **`README.md`**, **`openwrt/INSTALL.txt`**, **`package/luci-app-glinet-privacy/po/README`** updated.

---

## 1.2.2 (2026-04-08)

### Removed

- **OpenWrt package builds in-repo** — Deleted **`package/glinet-privacy/Makefile`**, **`package/luci-app-glinet-privacy/Makefile`**, **`package/BUILDING.txt`**, and **`.github/workflows/openwrt-packages.yml`** (entire **`.github`** tree). Distribution is **`install.sh`** / tarball only. **`README.md`**, **`openwrt/INSTALL.txt`**, **`docs/glinet-stock-ui.md`**, **`docs/backlog.md`**, **`package/luci-app-glinet-privacy/po/README`** updated accordingly.

---

## 1.2.1 (2026-04-08)

### Changed

- **`remove.sh`** — Dropped **`--keep-luci`**; uninstall always removes LuCI app files. **`README.md`** updated.

---

## 1.2.0 (2026-04-08)

### Removed

- **`apply-mullvad-wireguard.sh`** (and **`openwrt/usr/bin/`** copy), **`install.sh`** **`maybe_mullvad`**, and all Mullvad env / install references. VPN is **only** configured via **stock GL.iNet**; the kill switch continues to use **`privacy.main.wg_if`**.
- **DNS:** **`mullvad_dnsmasq`**, **`mullvad_dns` UCI**, and related LuCI options. **`apply-dns-policy.sh`** now only implements **`tor_dnsmasq`** vs **`default`**.

### Changed

- **LuCI** — Simplified **Kill switch** and **Tor, DNS & telemetry** copy; **`README.md`**, **`openwrt/INSTALL.txt`**, **`docs/*`**, **`package/glinet-privacy/Makefile`** descriptions updated. **`remove.sh`** no longer lists the removed script.

---

## 1.1.18 (2026-04-08)

### Changed

- **`install.sh`** — **Idempotent re-runs:** skips **`opkg update`** when all dependency packages are already installed (unless **`GLINET_PRIVACY_SKIP_OPKG_UPDATE`** is unset and something is missing); **telemetry** UCI defaults (`block_domains`, `disable_vendor_cloud`) are applied **once** (marker **`/etc/glinet-privacy/.telemetry-seeded`**) unless **`GLINET_PRIVACY_FORCE_TELEMETRY_SEED=1`**; **`dhcp.@dnsmasq[0].confdir`** is not duplicated. **Kernel:** skips **`kmod-wireguard`** when WireGuard is already loaded or **`/sys/module/wireguard`** exists. **Downloads:** tarball must be non-empty; **git** clone must contain **`package/glinet-privacy/files`**; **piped** `curl|sh` without **`GLINET_PRIVACY_TARBALL_URL`** / **`GLINET_PRIVACY_SRC`** fails with an explicit error. **`maybe_mullvad`** no longer spams the log when Mullvad env is unset. **`remove.sh`** removes **`.telemetry-seeded`**. **`README.md`** / **`install.sh --help`** document re-run behavior and env vars.

---

## 1.1.17 (2026-04-08)

### Added

- **`remove.sh`** — Uninstall helper for router installs: stops **`privacy-killswitch`** (flush rules), disables init scripts, deletes **`firewall.glinet_privacy`**, strips **`glinet-privacy`** lines from **`/etc/firewall.user`**, removes cron lines for **`privacy-killswitch-watchdog.sh`** / **`rotate_imei.sh`**, removes Tor **`torrc`** include for **`99-transparent.conf`**, **`/etc/dnsmasq.d/glinet-block.conf`**, all **`package/glinet-privacy/files`** paths (from source tree or built-in list), optional LuCI files, optional **`opkg remove`** for **`luci-app-glinet-privacy`** / **`glinet-privacy`**. **`README.md`** documents usage.

---

## 1.1.16 (2026-04-08)

### Changed

- **LuCI** — Removed the **WireGuard / Mullvad** tab; VPN/Mullvad is expected to be **preconfigured in stock GL.iNet** (WireGuard/OpenVPN clients; Mullvad supported). Guidance moved to **Kill switch** (map description + WireGuard interface help) and **`README.md`**. **`apply-mullvad-wireguard.sh`** remains available from the shell only. Removed **`wireguard.htm`**; **`install.sh`** installs **`overview.htm`** only.

---

## 1.1.15 (2026-04-08)

### Added

- **`docs/glinet-stock-ui.md`** — Clarifies that **GL.iNet has no public stock-web UI plugin SDK** for custom admin pages (with forum link); documents **OpenWrt SDK** vs **Plug-ins** vs **LuCI**; includes a **vendor feature-request template** for GL.iNet adoption or future UI integration. **`README.md`** links to it from the top and documentation table.

---

## 1.1.14 (2026-04-08)

### Added

- **GL.iNet firewall plugin companion**: **`/usr/bin/apply-privacy-firewall-includes.sh`** now registers UCI **`firewall.glinet_privacy`** and appends a **`glinet-privacy-fw-plugin`** line to **`/etc/firewall.user`** so **`fw-plugin.sh`** still runs after firewall reloads if a firmware upgrade drops the UCI include. **`postinst`**, **`uci-defaults/99-glinet-privacy-firewall`**, and **`install.sh`** **`register_firewall`** use this script. **`fw-plugin.sh`** comment updated; **`docs/devices.md`** and **`README.md`** describe the dual hook.

---

## 1.1.13 (2026-04-08)

### Fixed

- **LuCI (ucode) — translations on all pages**: **`luci.glinet_privacy.i18n`** now **`return`s `luci.i18n`** after **`loadc`**. **CBI** maps (**`killswitch.lua`**, **`plugins.lua`**, **`imei.lua`**) bind **`local translate = i18n.translate`** from that module so **`translate(...)`** is never nil outside the controller. **Controller** uses the same **`require("luci.glinet_privacy.i18n")`** for **`translate`** / **`translatef`**.

---

## 1.1.12 (2026-04-08)

### Fixed

- **LuCI controller** (`glinet_privacy.lua`): bind **`translate`** / **`translatef`** from **`luci.i18n`** and use **`translate(...)`** in **`index()`** instead of **`_(...)`**. On ucode-based LuCI (e.g. GL.iNet), **`build_status()`** no longer sees a global **`translate`**, which caused **`attempt to call global 'translate' (a nil value)`** on the overview page.

---

## 1.1.11 (2026-04-08)

### Fixed

- **`install.sh --with-luci`**: install **`luasrc/glinet_privacy/i18n.lua`** to **`/usr/lib/lua/luci/glinet_privacy/i18n.lua`** (was omitted; LuCI then failed with **`module 'luci.glinet_privacy.i18n' not found`**). Translations **`.lmo`** still come from the **`luci-app-glinet-privacy`** **ipk** build if you need non-English catalogs on the device.

---

## 1.1.10 (2026-04-08)

### Fixed

- **Telemetry / dnsmasq**: **`apply-telemetry.sh`** now **`mkdir -p /etc/dnsmasq.d`** before linking or copying **`glinet-block.conf`** (fixes `cp: can't create '/etc/dnsmasq.d/glinet-block.conf': No such file or directory` on GL.iNet firmware where **`/etc/dnsmasq.d`** is absent). **`install.sh`** **`setup_telemetry`** also ensures the directory exists before calling the script.

---

## 1.1.9 (2026-04-08)

### Added

- **README.md** — project overview, install and SDK pointers, link to [github.com/T-REX-XP/glinet_privacy_tuning](https://github.com/T-REX-XP/glinet_privacy_tuning).

### Changed

- **CI** (`.github/workflows/openwrt-packages.yml`): `concurrency.cancel-in-progress` only for **`pull_request`** (branch/tag pushes no longer abort in-flight SDK jobs); `actions/checkout@v6`, `actions/upload-artifact@v6` (Node.js 24–compatible actions per GitHub guidance).
- **CI — OpenWrt SDK**: pin **`ARCH`** to **`mipsel_24kc-openwrt-24.10`** and **`aarch64_cortex-a53-openwrt-24.10`**; **remove `EXTRA_FEEDS` for luci** — the SDK `feeds.conf.default` already declares feed **`luci`**; appending another `src-git luci …` line causes `./scripts/feeds update -a` to abort with **Duplicate feed name 'luci'** (see [OpenWrt `scripts/feeds`](https://github.com/openwrt/openwrt/blob/master/scripts/feeds) `parse_file`). **`package/BUILDING.txt`** notes the same.
- **Docs — remote install**: **`README.md`** and **`install.sh`** header clarify that **`curl` or `wget` must precede the raw URL** (otherwise ash reports `not found`); added **`wget -qO- … |`** example.

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
