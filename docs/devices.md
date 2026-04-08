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
