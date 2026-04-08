# Supported GL.iNet routers

The same packages and `install.sh` work on multiple models; **WAN defaults** depend on hardware.

| Profile (`glinet_privacy.hw.slug`) | Example models | LTE modem | Default `privacy.main.wan_dev` |
|-----------------------------------|----------------|-----------|--------------------------------|
| `puli_xe300` | **GL-XE300** (Puli) | Yes (Quectel) | `wwan0` when empty |
| `slate_ax1800` | **GL-AXT1800** (Slate AX) | No | empty (auto-detect via UCI / default route) |
| `gl_ax1800` | **GL-AX1800** (Flint) | No | empty; clears legacy `wwan0` if present |
| `generic` | Other boards | varies | empty |

Detection uses `/tmp/sysinfo/board_name`, `/etc/board.json` (`model.id`), and `ubus call system board` (substring match on lowercased text).

Run manually after changing hardware:

```sh
/usr/libexec/glinet-privacy/apply-device-profile.sh
uci commit privacy
```

Disable automatic WAN tuning per device:

```sh
uci set glinet_privacy.hw.auto_wan=0
uci commit glinet_privacy
```

**IMEI rotation** is only relevant on cellular models (e.g. Puli). On Slate AX / Flint, leave `rotate_imei.main.enabled` off.

## Firewall plugin (Tor NAT / hooks)

Transparent Tor and related rules are driven by **`/usr/libexec/glinet-privacy/fw-plugin.sh`**, registered in two ways:

1. **UCI** — `firewall.glinet_privacy` **include** (standard OpenWrt firewall4/fw3).
2. **GL.iNet companion** — a line tagged **`glinet-privacy-fw-plugin`** in **`/etc/firewall.user`** (installed by **`/usr/bin/apply-privacy-firewall-includes.sh`**). Some firmware upgrades reset custom UCI includes; the **`firewall.user`** hook still runs **`fw-plugin.sh`** on each firewall reload. Tor NAT iptables rules use **`-C` / `-I`** checks and remain safe if both paths execute.

## IMEI rotation — legal use and responsibility

**This is not legal advice.** Laws differ by country and change over time.

- **Risk:** Writing a non-factory or randomly generated IMEI to a modem can be **illegal** (criminal or administrative penalties) in many jurisdictions, or may breach your carrier agreement. Penalties can apply even for “privacy” or “testing” on a live public mobile network.
- **Typical lawful contexts:** work done by **mobile network operators**, **device manufacturers**, **accredited test labs**, or **authorized repair** channels; **private RF / shielded lab** testing with no attachment to a production network; and other situations where **written authorization** clearly covers IMEI programming.
- **Operator-only / authorized installs:** In project documentation, “operator-only” means **that class of authorized professional use**, not simply “the customer who pays the phone bill.” If you are not in one of those categories, assume you need **explicit permission** before using this feature.
- **Your responsibility:** You must determine whether IMEI changes are permitted **before** enabling boot rotation, cron, or manual runs of `/usr/bin/rotate_imei.sh`. The software is provided **as-is**; authors are not liable for misuse.
- **Script behaviour:** Each run logs a short **legal notice** to syslog unless you set `ROTATE_IMEI_SUPPRESS_LEGAL_LOG=1` (for example after you have documented compliance and want to quiet repeated cron messages). Suppressing the log does **not** reduce your legal obligations.

Related: `package/glinet-privacy/files/usr/bin/rotate_imei.sh` (header comments), LuCI **Services → GL.iNet Privacy → IMEI rotation** (boot, **cron schedule** via **`cron_enabled`** / **`cron_interval_hours`**, optional **`cron_suppress_legal_log`**).

## VPN kill switch: GL.iNet vendor UI vs glinet-privacy watchdog

GL.iNet stock firmware exposes **Block Non-VPN Traffic** / **VPN Kill Switch** in the admin **VPN Dashboard** (exact names vary by version). On many builds the global toggle lives in UCI as **`glvpn.general.block_non_vpn`** (see GL.iNet docs for *Internet Kill Switch* / *block non-VPN traffic*).

**This repository** ships **`privacy-killswitch-watchdog.sh`**, which inserts an iptables **`FORWARD`** DROP between LAN and the chosen WAN device when WireGuard/Tor checks fail (`privacy.main.*`). That is **independent** of the vendor VPN stack.

**Coexistence**

- **Prefer one primary strategy** when possible: either rely on the **vendor** kill switch (dashboard / `glvpn`) **or** on the **glinet-privacy** watchdog. Using both can **overlap** (e.g. redundant DROP rules) or confuse debugging; interface names may also differ (e.g. stock **wgclient** vs **`wg0`** from UCI WireGuard).
- **LuCI** (**Kill switch**): **`privacy.main.vendor_gl_vpn_killswitch`** — **Leave** (default) does not change `glvpn`; **On** / **Off** runs **`/usr/libexec/glinet-privacy/apply-vendor-vpn-killswitch.sh`** when **`/etc/config/glvpn`** and **`glvpn.general`** exist, then restarts **`glvpn`** if present.
- **Firmware v4.8+** may move behaviour into per-tunnel options and **nftables**; if **`glvpn.general`** is missing, the script logs and skips — use the **web UI** for those cases.

Related: **`docs/backlog.md`** (Epic 3), **`package/glinet-privacy/files/usr/libexec/glinet-privacy/apply-vendor-vpn-killswitch.sh`**.
