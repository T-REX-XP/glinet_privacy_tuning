# GL.iNet Privacy tuning (OpenWrt)

Privacy-oriented scripts, UCI, firewall hooks, and an optional LuCI UI for GL.iNet routers running OpenWrt: kill switch watchdog, Tor transparent NAT, DNS policy helpers, telemetry blocking, Mullvad WireGuard apply script, and optional Quectel IMEI rotation (cellular models).

**Repository:** [github.com/T-REX-XP/glinet_privacy_tuning](https://github.com/T-REX-XP/glinet_privacy_tuning)

## Features

- **Kill switch** — Watchdog script and iptables rules to block forwarded traffic when VPN/Tor health checks fail; optional integration with GL.iNet stock `glvpn` “block non-VPN” where present.
- **Tor** — Transparent proxy via firewall include + `torrc` fragments; optional LAN DNS forwarding and TCP/53 handling (see UCI `glinet_privacy`).
- **DNS policy** — `dnsmasq` modes for default, Tor DNSPort, or Mullvad DNS (`apply-dns-policy.sh`).
- **Mullvad WireGuard** — Helper script to apply WireGuard client settings from environment variables (no secrets stored in LuCI).
- **Telemetry** — Disable cloud features where possible, optional package removal, dnsmasq blocklist for known GL.iNet endpoints.
- **IMEI rotation** (LTE hardware only) — Script + init/cron examples; **high legal risk** on public networks — read [docs/devices.md](docs/devices.md) before enabling.
- **LuCI** — `luci-app-glinet-privacy` under **Services → GL.iNet Privacy** (overview, kill switch, IMEI, Tor/DNS/telemetry, Mullvad reference page).
- **i18n** — gettext `.po` catalogs under `package/luci-app-glinet-privacy/po/`; regenerate with `tools/extract-luci-i18n-strings.py` and `tools/i18n-build-po-from-pot.py` (see [package/luci-app-glinet-privacy/po/README](package/luci-app-glinet-privacy/po/README)).

## Quick install (on the router)

Requires **OpenWrt** (e.g. GL.iNet stock firmware based on OpenWrt). Run as **root**.

From a tarball URL (replace `USER/REPO` with this repo):

```sh
curl -fsSL https://raw.githubusercontent.com/T-REX-XP/glinet_privacy_tuning/main/install.sh | \
  GLINET_PRIVACY_TARBALL_URL=https://github.com/T-REX-XP/glinet_privacy_tuning/archive/refs/heads/main.tar.gz \
  sh -s -- --with-luci
```

From a git clone on the device:

```sh
sh install.sh --with-luci
```

Useful flags: `--minimal` (files + firewall/profile only), `--with-imei-boot`, `--with-imei-cron`. Full options and environment variables are documented in the [install.sh](install.sh) header.

## Building `.ipk` packages (OpenWrt SDK)

To compile **`glinet-privacy`** and **`luci-app-glinet-privacy`** as opkg packages, see [package/BUILDING.txt](package/BUILDING.txt). CI (`.github/workflows/openwrt-packages.yml`) builds against the official OpenWrt SDK with the LuCI feed.

Version and changelog: [package/version.mk](package/version.mk), [changes.md](changes.md).

## Documentation

| Document | Contents |
|----------|----------|
| [docs/devices.md](docs/devices.md) | Supported models, WAN defaults, vendor kill switch notes, **IMEI legal notice** |
| [docs/requirements.md](docs/requirements.md) | Original design goals (reference) |
| [docs/backlog.md](docs/backlog.md) | Implementation checklist |

## License

SPDX: **MIT** (see `Makefile` headers under `package/`).
