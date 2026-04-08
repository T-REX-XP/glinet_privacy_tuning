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
- [x] **IMEI LuCI diagnostics** — Read-only **mmcli** / **uqmi** hints on **IMEI rotation** when tools are installed (`imei_detect.lua` **`get_mmcli_uqmi_hints`**, `imei.htm`).

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

- [x] **nft / iptables-nft LuCI status** — **`firewall_status.lua`** extends Overview + Tor badge checks (**v1.2.23**).
- [ ] **nftables-native watchdog** — **`privacy-killswitch-watchdog.sh`** / **`firewall.privacy-tor.sh`** still assume **`iptables`** (xtables-nft on stock); raw **nft-only** drop/redirect not implemented in shell.

---

## Epic 4: De-bloating and anti-telemetry

- [x] **Task 4.1** — Disable GoodCloud / cloud: `glconfig.cloud.enable=0`, `disable-glinet-telemetry.sh`, LuCI **`disable_vendor_cloud`**.
- [x] **Task 4.2** — Remote support / tracking packages: optional `remove_cloud_packages` + `opkg remove` in `disable-glinet-telemetry.sh`.
- [x] **Task 4.3** — Telemetry domains: `/etc/glinet-privacy/glinet-block.conf` → `/etc/dnsmasq.d` via `apply-telemetry.sh`, UCI **`block_domains`**.

**Open / follow-up**

- [ ] Expand domain list per firmware / region if new endpoints appear (keep `glinet-block.conf` as the single source).

---

## Misc (cross-cutting)

- [x] **SPDX + `PKG_LICENSE`** — **`GPL-2.0-only`** in **`package/*/Makefile`**, **`LICENSE`** at repo root; SPDX file headers on sources (**v1.2.19**).
- [x] **OpenWrt feed docs + Makefile hardening** — **`feeds.conf.example`**, **`package/OPENWRT-BUILD.txt`**, **`conffiles`** / **`postinst`** on **`glinet-privacy`** and **`luci-app-glinet-privacy`** (**v1.2.20**).
- [ ] Automated tests in CI (none yet; no on-device smoke tests).
- [x] LuCI i18n `.po` files if translations are required beyond English strings in templates (`po/`, `tools/extract-luci-i18n-strings.py`, `tools/i18n-build-po-from-pot.py`; optional **`po2lmo`** on a host with LuCI tools, then copy **`glinet_privacy.<lang>.lmo`** to **`/usr/lib/lua/luci/i18n/`** — see `package/luci-app-glinet-privacy/po/README`).
- [x] **LuCI security hardening (v1.2.13)** — **`sanitize.lua`** (ifnames, tty paths, IPv4/CIDR, ports); **`rpcd` ACL** write scope narrowed; **Verify** router **`verify_ip`** path + browser/router mode + HTML **`esc()`**; **Overview** **`pcdata(details)`**. *Still open:* **nft**-native status, fully offline Verify — see **`docs/contributor-review.md`** backlog.
- [x] **LuCI CSRF (v1.2.17)** — Custom POST forms include session **`token`**; **`csrf.verify_post()`** in controller (see **`docs/contributor-review.md`** §4).
- [x] **LuCI Overview VPN ifstatus (v1.2.14)** — **`vpn_probe.lua`**: **`ifstatus`** / **`ubus`** for **`wg_if`** and **`network`** OpenVPN/WireGuard sections; enriches **WireGuard** Overview row (see **`changes.md`**).
- [x] **LuCI optional vendor ubus (v1.2.16)** — **`vendor_ubus.lua`** + **`docs/vendor-ubus.md`**: read-only **`ubus`** whitelist, UCI opt-in / **`min_release_substr`**; UI on Overview / Kill switch / Tor-DNS.
- [x] **LuCI `menu.d` / ucode pagetree (v1.2.18)** — **`luci-app-glinet-privacy.json`** when **OpenWrt ≥ 22.03** (or **`GLINET_PRIVACY_LUCI_MENU_JSON=1`**); Lua **`index()`** skipped via **`luci-use-menu-d`** marker; **`call()`** handlers still Lua (see **`changes.md`**).
