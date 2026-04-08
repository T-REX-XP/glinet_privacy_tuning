# Privacy-first router backlog (GL-XE300 Puli, GL-AXT1800 Slate AX, …)

Implementation status for **`glinet-privacy`** / **`luci-app-glinet-privacy`**. Source of truth for releases: `package/version.mk` and `changes.md`.

---

## Epic 1: Cellular anonymity (EG25-G and similar)

- [x] **Task 1.1** — Valid IMEI generation (Luhn check digit): `package/glinet-privacy/files/usr/bin/rotate_imei.sh` (`luhn_check_digit`, `generate_imei`).
- [x] **Task 1.2** — AT command to modem TTY: same script (`send_at_imei`, `AT+EGMR=1,7,"…"`), `find_modem_tty` (`/dev/ttyUSB2` / `ttyUSB3` / …).
- [x] **Task 1.3** — Init on boot: `package/glinet-privacy/files/etc/init.d/rotate_imei`, UCI `rotate_imei`, `install.sh --with-imei-boot`.
- [x] **Task 1.4** — Cron rotation: `package/glinet-privacy/files/etc/crontabs/root.rotate_imei.example`, `install.sh --with-imei-cron`.

**Open / follow-up**

- [x] **Legal documentation** — `docs/devices.md` (IMEI section), script header + `legal_notice()` in `rotate_imei.sh`, LuCI / UCI / init comments, `ROTATE_IMEI_SUPPRESS_LEGAL_LOG` for cron.

---

## Epic 2: Secure tunneling (VPN & Tor)

- [x] **Task 2.1** — VPN via stock GL.iNet UI; kill switch **`privacy.main.wg_if`** documented on LuCI **Kill switch** (removed standalone Mullvad apply script).
- [x] **Task 2.2** — Tor package + config: `install.sh` opkg, `package/glinet-privacy/files/etc/tor/torrc.d/99-transparent.conf`.
- [x] **Task 2.3** — Tor transparent proxy (LAN → Tor): `fw-plugin.sh`, `firewall.privacy-tor.sh`, `glinet_privacy` UCI `tor_transparent`.
- [x] **Task 2.4** — **DNS policy**: UCI **`glinet_privacy.dns`** (`dns_policy` **`default`** / **`tor_dnsmasq`**), **`apply-dns-policy.sh`**, LuCI **Tor, DNS & telemetry**; **`firewall.privacy-tor.sh`** adds LAN **TCP/53** → Tor DNSPort and optional **LAN DoT (853) drop**.

---

## Epic 3: Hardened kill switch

- [x] **Task 3.1** — **Stock GL.iNet VPN kill switch**: **`privacy.main.vendor_gl_vpn_killswitch`** (`leave` / `on` / `off`), **`apply-vendor-vpn-killswitch.sh`** (`glvpn.general.block_non_vpn` when present), LuCI **Kill switch**, **`docs/devices.md`** (coexistence with privacy watchdog).
- [x] **Task 3.2** — Block clear-net when unhealthy: `package/glinet-privacy/files/usr/bin/privacy-killswitch-watchdog.sh` (iptables `FORWARD` DROP with comment `privacy-killswitch-drop`), UCI `privacy.main`.
- [x] **Task 3.3** — Watchdog + cron: same script, `package/glinet-privacy/files/etc/init.d/privacy-killswitch`, `install.sh` cron line, LuCI killswitch.

**Open / follow-up**

- [ ] **nftables-native** path on images without iptables-nft compat (today assumes `iptables`/`iptables-save` as on typical GL.iNet OpenWrt).

---

## Epic 4: De-bloating and anti-telemetry

- [x] **Task 4.1** — Disable GoodCloud / cloud: `glconfig.cloud.enable=0`, `disable-glinet-telemetry.sh`, LuCI **`disable_vendor_cloud`**.
- [x] **Task 4.2** — Remote support / tracking packages: optional `remove_cloud_packages` + `opkg remove` in `disable-glinet-telemetry.sh`.
- [x] **Task 4.3** — Telemetry domains: `/etc/glinet-privacy/glinet-block.conf` → `/etc/dnsmasq.d` via `apply-telemetry.sh`, UCI **`block_domains`**.

**Open / follow-up**

- [ ] Expand domain list per firmware / region if new endpoints appear (keep `glinet-block.conf` as the single source).

---

## Misc (cross-cutting)

- [ ] Automated tests in CI (none yet; no on-device smoke tests).
- [x] LuCI i18n `.po` files if translations are required beyond English strings in templates (`po/`, `tools/extract-luci-i18n-strings.py`, `tools/i18n-build-po-from-pot.py`; optional **`po2lmo`** on a host with LuCI tools, then copy **`glinet_privacy.<lang>.lmo`** to **`/usr/lib/lua/luci/i18n/`** — see `package/luci-app-glinet-privacy/po/README`).
