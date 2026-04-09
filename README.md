# GL.iNet Privacy tuning

**Supported target:** **GL.iNet routers** running **stock GL.iNet firmware** (OpenWrt-based). This project is **not** intended for generic OpenWrt builds or non-GL.iNet hardware; **`install.sh`** aborts if the image is not recognized as GL.iNet.

Privacy-oriented scripts, UCI, firewall hooks, and a LuCI UI (installed by default; **`install.sh --without-luci`** skips it): kill switch watchdog, Tor transparent NAT, optional dnsmasq→Tor DNS policy, telemetry blocking, and optional Quectel IMEI rotation (cellular models). **VPN** is configured in **stock GL.iNet** (WireGuard/OpenVPN); this project only watches the tunnel interface you name in UCI.

**Repository:** [https://github.com/T-REX-XP/glinet_privacy_tuning](https://github.com/T-REX-XP/glinet_privacy_tuning)

**Stock GL.iNet web UI:** this project’s UI is **LuCI** (and CLI). GL.iNet does not currently ship a public SDK for custom stock-admin pages; vendor adoption or a future official SDK would be separate — see [docs/glinet-stock-ui.md](docs/glinet-stock-ui.md).

## Privilege model & network exposure

- **Root on the router** — **`install.sh`** / **`remove.sh`**, **`etc/init.d/*`**, **`usr/bin/*`**, **`usr/libexec/glinet-privacy/*`**, cron lines, and **`uci-defaults`** run as **root**. **LuCI** is served by **uhttpd** (stock GL.iNet); saving forms runs controller code that calls **`luci.sys.call`** / **`sys.exec`** — still **root** for service and firewall actions.
- **UCI packages touched** — Primary: **`privacy`**, **`glinet_privacy`**, **`rotate_imei`**. Installer and **`apply-vendor-vpn-killswitch.sh`** may change **`glvpn`** when present. **`firewall`** gains **`firewall.glinet_privacy`** (include path). **`apply-dns-policy.sh`** / stock **`/etc/config/dhcp`** may adjust **dnsmasq** options when you enable Tor DNS policy or telemetry blocklist paths. Do not expose LuCI or these UCI editors to untrusted users.
- **Outbound URLs (optional / user-driven)** — **Verify** can call **api.ipify.org** from the browser or from the router (**`verify_ip`**). Optional browser geo (**e.g. ipwho.is**) is documented on the Verify page. **Remote install** uses URLs you set (**`GLINET_PRIVACY_TARBALL_URL`**, **`GLINET_PRIVACY_GIT_URL`**, **`raw.githubusercontent.com`** for `install.sh`). No other standing phone-home is required for core operation.
- **Diagnostics** — The **Overview** **syslog** strip shows recent **`logread`** lines for this project’s **`logger -t`** tags; many **`sys.call`** apply helpers still discard stderr (`>/dev/null`); check **System log** after a failed save if something looks wrong.

## Features

- **Kill switch** — Watchdog script and iptables rules to block forwarded traffic when VPN/Tor health checks fail; optional integration with GL.iNet stock `glvpn` “block non-VPN” where present.
- **Tor** — Transparent proxy via **`fw-plugin.sh`** (UCI **`firewall.glinet_privacy`** include + **`/etc/firewall.user`** companion hook for GL.iNet-friendly persistence) and `torrc` fragments; optional LAN DNS forwarding and TCP/53 handling (see UCI `glinet_privacy`).
- **DNS policy** — `apply-dns-policy.sh`: leave dnsmasq unchanged, or forward to **Tor** DNSPort (`glinet_privacy.dns.dns_policy`).
- **VPN** — Configure WireGuard/OpenVPN in the **GL.iNet admin**, then set **`privacy.main.wg_if`** (and related kill switch options) in LuCI to match the running interface.
- **Telemetry** — Disable cloud features where possible, optional package removal, dnsmasq blocklist for known GL.iNet endpoints.
- **IMEI rotation** (LTE hardware only) — Script + init/cron examples; **high legal risk** on public networks — read [docs/devices.md](docs/devices.md) before enabling.
- **LuCI** — `luci-app-glinet-privacy` under **Services → GL.iNet Privacy** (overview, kill switch, IMEI, Tor/DNS/telemetry).
- **i18n** — Standard LuCI domain **`glinet_privacy`**: gettext **`po/`** + **`po2lmo`** in **`package/luci-app-glinet-privacy/Makefile`** (installs **`glinet_privacy.<lang>.lmo`**); **`install.sh`** compiles **`.lmo`** when **`po2lmo`** exists on the router. Regenerate strings with **`tools/extract-luci-i18n-strings.py`** / **`tools/i18n-build-po-from-pot.py`**; Weblate-oriented notes in [package/luci-app-glinet-privacy/po/README](package/luci-app-glinet-privacy/po/README).

## Package build from SDK (optional)

To compile **`glinet-privacy`** / **`luci-app-glinet-privacy`** **`.ipk`** files (for installation via **`opkg`** on GL.iNet devices), use an OpenWrt-compatible SDK aligned with your router’s firmware. See [**`feeds.conf.example`**](feeds.conf.example) and [**`package/OPENWRT-BUILD.txt`](package/OPENWRT-BUILD.txt)** (and [**`openwrt/INSTALL.txt`](openwrt/INSTALL.txt)**). Runtime install on the router remains **`install.sh`** from this repo.

## Quick install (on the router)

Requires a **GL.iNet router** with **stock firmware**. Run as **root**.

**Remote install** — the script must be **downloaded** first. Start the line with `curl` or `wget`; pasting only the `https://…` URL makes the shell try to run the URL as a command (`not found`).

**Do not paste installer log lines** (`Using repo root:`, `opkg: …`, `Done. …`) back into the shell — they are messages, not commands.

**`GLINET_PRIVACY_TARBALL_URL`** must be the **`.tar.gz`** archive URL (the tree must contain `package/glinet-privacy/files`), not the bare GitHub repo page.

With **curl** (install `curl` with `opkg update && opkg install curl` if needed). One line (no `\` line breaks — safest for copy-paste):

```sh
curl -fsSL https://raw.githubusercontent.com/T-REX-XP/glinet_privacy_tuning/main/install.sh | GLINET_PRIVACY_TARBALL_URL=https://github.com/T-REX-XP/glinet_privacy_tuning/archive/refs/heads/main.tar.gz sh -s --
```

With flags (example `--with-luci` is default; shown for clarity):

```sh
curl -fsSL https://raw.githubusercontent.com/T-REX-XP/glinet_privacy_tuning/main/install.sh | GLINET_PRIVACY_TARBALL_URL=https://github.com/T-REX-XP/glinet_privacy_tuning/archive/refs/heads/main.tar.gz sh -s -- --with-luci
```

With **wget** (common on busybox systems):

```sh
wget -qO- https://raw.githubusercontent.com/T-REX-XP/glinet_privacy_tuning/main/install.sh | GLINET_PRIVACY_TARBALL_URL=https://github.com/T-REX-XP/glinet_privacy_tuning/archive/refs/heads/main.tar.gz sh -s --
```

From a git clone on the device:

```sh
sh install.sh
```

Useful flags: `--without-luci` (skip LuCI files; default is to install them), `--minimal` (files + firewall/profile only), `--with-imei-boot`, `--with-imei-cron` (enables scheduled IMEI rotation; default 6h, set **`cron_interval_hours`** in LuCI → IMEI rotation). Full options and environment variables are documented in the [install.sh](install.sh) header.

**Re-running `install.sh`** is safe: **`opkg update`** runs only when at least one dependency is missing (including **`iptables-nft`** as the iptables stack on current firmware); **`kmod-wireguard`** is skipped if the WireGuard module is already present; telemetry defaults are seeded **once** (see **`/etc/glinet-privacy/.telemetry-seeded`**); **`dhcp` `confdir`** is not duplicated. **`GLINET_PRIVACY_SKIP_OPKG_UPDATE=1`** skips the feed update (faster repeat installs; may fail offline if a package is missing). **`GLINET_PRIVACY_FORCE_TELEMETRY_SEED=1`** re-applies the installer telemetry UCI toggles.

**Piping the script** (`curl … | sh`) requires **`GLINET_PRIVACY_TARBALL_URL`** pointing at a **source tree** archive (must contain **`package/glinet-privacy/files`**), or **`GLINET_PRIVACY_SRC`**.

**LuCI** is implemented as **JavaScript** views (LuCI **`view`** API) plus **`/usr/libexec/glinet-privacy/luci-json.sh`** for status JSON (**`rpcd`** **`file.exec`**). **`luci-lua-runtime`** is **not** required. Use **`--without-luci`** for CLI-only.

## Remove (uninstall on the router)

Run as **root** from a **git clone** of this repo (so paths match), or set **`GLINET_PRIVACY_SRC`**, or use the embedded file list:

```sh
sh remove.sh
```

Option: **`--opkg`** — also run `opkg remove luci-app-glinet-privacy glinet-privacy` when those ipks are installed. The script always removes LuCI app files under `/usr/lib/lua/luci/...` when present. It stops the killswitch (flushes iptables rules), removes firewall UCI and `/etc/firewall.user` lines, cron lines, Tor include, dnsmasq blocklist symlink, project files, and `/etc/config/{privacy,glinet_privacy,rotate_imei}`. It does **not** remove unrelated opkg packages (e.g. `tor`) unless you use **`--opkg`** for our packages only.

Version and changelog: [package/version.mk](package/version.mk), [changes.md](changes.md).

## Documentation

| Document | Contents |
|----------|----------|
| [docs/devices.md](docs/devices.md) | Supported models, WAN defaults, vendor kill switch notes, **IMEI legal notice** |
| [docs/requirements.md](docs/requirements.md) | Original design goals (reference) |
| [docs/backlog.md](docs/backlog.md) | Implementation checklist |
| [docs/glinet-stock-ui.md](docs/glinet-stock-ui.md) | Stock GL.iNet UI vs LuCI; vendor outreach template |

## License

**GPL-2.0-only** — full text in [`LICENSE`](LICENSE); package metadata uses **`PKG_LICENSE:=GPL-2.0-only`** in `package/glinet-privacy/Makefile` and `package/luci-app-glinet-privacy/Makefile`. Source files carry **`SPDX-License-Identifier: GPL-2.0-only`** where a comment syntax exists.
