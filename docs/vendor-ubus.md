# Optional vendor / system ubus reads (LuCI)

The LuCI module **`luci.glinet_privacy.vendor_ubus`** runs **read-only** `ubus` calls for supplemental VPN/DNS-related **status** only when:

1. **Documented below** — each call has a stable reference (OpenWrt docs/wiki or GL.iNet / GSDK / router docs).
2. **Opt-in** — UCI **`glinet_privacy.vendor_ubus.enabled`** is **`1`** (default **`0`**).
3. **Version gate (optional)** — if **`glinet_privacy.vendor_ubus.min_release_substr`** is non-empty, the JSON from **`ubus call system board`** must contain that substring (e.g. a firmware tag you verified on your fleet).

There are **no** new **rpcd** plugins in this repository: LuCI runs these calls **server-side** via a fixed whitelist (no user-controlled object or method names). **Do not** extend the Lua whitelist without adding a row here and a citation.

## References

- OpenWrt **ubus** overview: [OpenWrt ubus](https://openwrt.org/docs/guide-developer/ubus) ( **`system`**, **`network`**, **`dhcp`** objects on typical images).
- GL.iNet router documentation hub: [GL.iNet Router Docs](https://docs.gl-inet.com/router/en/) — use **your** firmware’s public API / developer notes when adding vendor-specific objects. If an object is only discoverable via **`ubus -v list`** on the device and is **not** published by the vendor, keep it **out** of the in-tree whitelist.

## Whitelisted calls (in code: `vendor_ubus.lua`)

| ID | Command | Args | Doc basis |
|----|---------|------|-----------|
| `system_board` | `ubus call system board` | (none / empty) | OpenWrt **`system`** object; output includes **`release`** text used for version gating. |
| `network_iface` | `ubus call network.interface.<name> status` | `{}` | OpenWrt **`network.interface.<logical>`** ; **`<name>`** is the first existing UCI **`network`** interface among **`wan`**, **`wwan`**, **`modem`** (section must exist). |
| `dhcp_ipv4leases` | `ubus call dhcp ipv4leases` | `{}` | OpenWrt **`dhcp`** object where present; DHCP IPv4 leases (diagnostic context for LAN DNS/DHCP). |

## UCI

```text
config vendor_ubus 'vendor_ubus'
	option enabled '0'
	# If non-empty, substring must appear in `ubus call system board` output (version gate).
	option min_release_substr ''
```

## GSDK / vendor-only calls

To add e.g. a GL.iNet **`ubus`** object for VPN dashboard state:

1. Obtain a **published** method list or doc revision tied to firmware (GSDK release note, official developer article, or tagged firmware source).
2. Add a row to the table above with the exact **`ubus call ...`** shape and citation.
3. Add a matching entry to **`DOCUMENTED_PROBES`** in **`vendor_ubus.lua`** with the same **`id`**; use only **read-only** invocations with **fixed** JSON arguments as documented.
