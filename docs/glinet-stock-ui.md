# GL.iNet stock web UI vs this project

This repository ships **OpenWrt packages** (`glinet-privacy`, `luci-app-glinet-privacy`) and **LuCI** under **Services → GL.iNet Privacy**. That is **not** the same as a panel inside GL.iNet’s simplified **stock** admin (the non-LuCI UI).

## What GL.iNet offers today

| Path | Purpose |
|------|---------|
| **[OpenWrt / GL.iNet SDK](https://github.com/gl-inet/sdk)** | Build **`.ipk`** packages for the router (CLI, **Plug-ins** / `opkg`). This is how **`glinet-privacy`** is built. |
| **Plug-ins** in the stock UI | Wrapper around **`opkg`** — install/remove packages, not a framework for arbitrary new stock-UI pages. See [Plug-ins (docs)](https://docs.gl-inet.com/router/en/4/interface_guide/plugins/). |
| **LuCI** | Standard OpenWrt web UI; **this project’s** settings live here. Access: **System → Advanced settings → Go to LuCI** (wording may vary by version). |

## Stock UI plugin / SDK (custom admin pages)

GL.iNet has **not** published a public **SDK to build custom pages** for the proprietary v4 web admin. Staff have stated there is **no** such SDK **at the moment** (see forum: [SDK for Gl.iNet router UI](https://forum.gl-inet.com/t/sdk-for-gl-inet-router-ui/66233)). Older **dev.gl-iNet.com** API docs have often been unavailable; treat any HTTP API as **undocumented** unless GL.iNet publishes it again.

**Conclusion:** Integrating **glinet-privacy** into the **stock** GL.iNet UI (same UX as built-in VPN/GoodCloud) is **not** something this LuCI package can do alone; it would require **vendor work** or a **future official SDK** from GL.iNet.

## Option A — Ask GL.iNet to adopt or ship integration

Reasonable asks:

1. **Ship or endorse** `glinet-privacy` / `luci-app-glinet-privacy` in a **feed** or **optional package** list with a doc link to LuCI.
2. **Feature request:** a **minimal stock-UI** page that toggles a few **UCI** keys (`privacy`, `glinet_privacy`) and links to **LuCI** for advanced settings — still **their** frontend work.

You can open a thread in the **[GL.iNet forum](https://forum.gl-inet.com/)** (Routers / Feature requests) or use **[official contact](https://www.gl-inet.com/contacts/)**. Below is a **template** you can adapt (not from GL.iNet; adjust to your model and needs).

---

**Subject (example):** Feature request: privacy toolkit integration (kill switch / Tor / telemetry) for stock UI or curated packages

**Body (example):**

> We use community project **glinet_privacy_tuning** (OpenWrt packages + LuCI) for kill switch, Tor transparent proxy, DNS policy, and telemetry controls. Configuration today is via **LuCI** or SSH.
>
> Please consider one of:
> 1. **Curated opkg** / documentation link so users can install from Plug-ins safely, or  
> 2. A **small stock-UI** section that surfaces core toggles and links to LuCI for advanced options, or  
> 3. A **published, supported** way to extend the v4 web UI if that becomes available.
>
> Reference: `https://github.com/T-REX-XP/glinet_privacy_tuning`  
> Thank you.

---

## Option B — Separate effort (only if GL.iNet ships an SDK)

If GL.iNet later publishes a **documented** plugin or extension API for the stock UI, a **separate** repository (e.g. `glinet-privacy-gl-ui`) would be appropriate: their stack, build chain, and signing — **out of scope** for the LuCI tree in this repo.

Until then, **LuCI + SSH/UCI** remain the supported surfaces for this project.
