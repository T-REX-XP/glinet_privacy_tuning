# GL.iNet Privacy — Contributor review

**Scope:** `luci-app-glinet-privacy`, `sanitize.lua`, **`csrf.lua`**, `net_probe.lua`, **`vpn_probe.lua`** (ifstatus / ubus VPN), **`vendor_ubus.lua`** (opt-in documented ubus readout), **`root/usr/share/luci/menu.d/luci-app-glinet-privacy.json`** (OpenWrt 22.03+ pagetree), controller actions, templates (`overview`, `killswitch`, `imei`, `tor_dns`, `verify`, `vendor_ubus_card`, `csrf_field`), authenticated **`verify_ip`** JSON endpoint, `install.sh`, rpcd ACL.  
**Perspectives:** security hardening, OpenWrt packaging / upstream norms, maintainability / best practices, **composition with GL.iNet stock (OOTB) features**.  
**Companion backlog:** epic-level tasks live in **`docs/backlog.md`**; this file adds reviewer lens, security notes, and the **P0–P3** feature backlog.

---

## Executive summary

The LuCI surface is **coherent and user-oriented**: UCI-backed forms, shared styling, runtime probing for LAN/WAN/Tor hints, and scripts invoked via **fixed paths** (good). As of **v1.2.13**, **`sanitize.lua`** and a **narrowed rpcd write ACL** address the earlier **command-injection** and **over-broad UCI write** concerns for this app’s LuCI layer. Remaining gaps for an upstream-quality package include: **iptables-centric** status checks on **nft-first** images (see **`docs/backlog.md`** Epic 3 follow-up), **optional third-party calls** on **Verify** (browser geo / router→ipify; fully offline mode still open), **legacy LuCI Lua** (`module()`, `package.seeall`), **no in-tree OpenWrt `Makefile` feed layout**, and **composition** with stock **Network → DNS** / **VPN Dashboard** (OOTB checklist — P1 backlog below). **CSRF** for custom POST forms is **implemented** (**v1.2.17+**: hidden **`token`** = session **`authtoken`**, same model as stock **`dispatcher.test_post_security`**).

---

## Strengths (keep doing this)

| Area | Observation |
|------|-------------|
| **Separation of concerns** | Firewall / watchdog logic lives in shell under `/usr/libexec` and `/usr/bin`; LuCI mostly edits UCI and triggers apply — easier to audit than embedding `iptables` in pages. |
| **UCI as contract** | `privacy`, `glinet_privacy`, `rotate_imei` are clear configuration boundaries; templates align with apply scripts. |
| **GL.iNet coexistence (partial)** | Vendor **VPN kill switch** via `glvpn`; telemetry scripts target vendor cloud UCI; **Tor** firewall path survives some stock upgrade resets via **`/etc/firewall.user`** (see `docs/devices.md`). |
| **Input narrowing** | **`sanitize.lua`**: ifnames, modem **`/dev/tty…`**, IPv4, LAN CIDR, ports on POST + probes; `vendor_gl_vpn_killswitch` enum; IMEI TAC digits + length. |
| **Template escaping** | **`pcdata()`** on Overview **`it.detail`**; **Verify** builds HTML with **`esc()`** (`&`, `<`, `>`, `"`); several views use **`pcdata()`** for interface strings. |
| **Runtime hints** | `net_probe.lua` uses kernel **`ip`** output and UCI — appropriate for OpenWrt. |
| **External links** | Verify / tools use `rel="noopener noreferrer"` where applicable. |

---

## GL.iNet firmware — OOTB features vs this package

Stock **GL.iNet 4.x** (and related docs) emphasises **VPN Dashboard** (client/server, global vs policy-based routing, kill switch / *block non-VPN traffic* on supported builds), **Network → DNS** (*Automatic* / *Encrypted DNS* / *Manual* / *DNS Proxy*, rebinding protection, “override DNS for all clients”, VPN vs custom DNS precedence), optional **Applications** (e.g. AdGuard Home on some images), and **diagnostics / logs**. This repo **should not duplicate** those UIs; it should **compose** with them.

| Stock theme | Already used / reflected here | Gap / opportunity |
|-------------|------------------------------|-------------------|
| **VPN kill switch / block non-VPN** | `apply-vendor-vpn-killswitch.sh`, LuCI **Kill switch**, live `glvpn` read | **v4.8+** / **nft**-heavy builds may differ; extend detection and user copy (see backlog). |
| **VPN client (WireGuard / OpenVPN)** | Kill switch **wg_if** + **datalist**; docs mention **wgclient** | No read-only **sync** with VPN Dashboard state (tunnel up, policy mode); add probes + links to stock UI. |
| **Secure / Encrypted DNS** | Our **Tor forward** / DoT drop options touch **dnsmasq** | Risk of **fighting** stock Encrypted DNS stack; need **conflict hints** and a **recommended modes** matrix in docs + LuCI. |
| **GoodCloud / telemetry** | `disable_vendor_cloud`, blocklist, `remove_cloud_packages` | Could add explicit **checkpoint** “Stock cloud disabled?” aligned with **glconfig** / services. |
| **Privacy / leak checks** | **Verify** tab: external link cards + **Browser** / **Router WAN** IP check (**`verify_ip`** → ipify from router) | **Fully offline** check mode; vendor UI **checklist** copy; optional deeper **router-local** probes (backlog). |

Reference material for wording and menu paths: [GL.iNet firmware features](https://www.gl-inet.com/support/firmware-features/), [DNS interface (docs)](https://docs.gl-inet.com/router/en/4/interface_guide/dns/), [VPN Dashboard (docs)](https://docs.gl-inet.com/router/en/4/interface_guide/vpn_dashboard_v4.7/).

---

## Security findings

### High priority

1. **Command injection via UCI-sourced strings in shell one-liners**  
   - **Risk (historical):** `build_status()` used `ip link show .. wg_if ..`; **`net_probe`** used `ip .. dev ..` with UCI-derived names — shell metacharacters in UCI could alter the command (admin-only; still defense-in-depth issue).  
   - **Mitigation:** Validate with a strict pattern (Linux ifname length / charset) before **`sys.call` / `sys.exec`**; reject or normalize on **save** and **before probes**.  
   - **Status (v1.2.13+):** Implemented — **`luci/glinet_privacy/sanitize.lua`**; wired in **`glinet_privacy.lua`** (POST + `build_status`) and **`net_probe.lua`**. **`install.sh`** installs **`sanitize.lua`**.

2. **rpcd ACL grants wide UCI write** (`luci-app-glinet-privacy.json`)  
   - **Risk (historical):** **Write** on **`network`**, **`firewall`**, **`dhcp`** was broader than packages this LuCI app **commits** via its forms.  
   - **Mitigation:** **Write** only packages actually modified; keep **read** for probes where the stack enforces rpcd ACL.  
   - **Status (v1.2.13+):** Implemented — **write:** `privacy`, `rotate_imei`, `glinet_privacy`, `glvpn`; **read:** adds **`network`**, **`firewall`**, **`dhcp`**, **`glvpn`** for status/probes. JSON **description** explains the split.

### Medium priority

3. **Verify tab: third-party endpoints**  
   - Browser `fetch()` to **api.ipify.org** and **ipwho.is** from a logged-in LuCI session leaks **client public IP** to those operators and depends on their **availability / CORS / trust**.  
   - **Recommendation:** Document in UI copy; optionally proxy via router (uhttpd/cgi — higher effort) or offer “offline / no external check” mode; consider **Content-Security-Policy** implications if LuCI tightens CSP globally.  
   - **Status:** Partially implemented — **Router WAN** mode: authenticated **`verify_ip`** `call()` fetches **ipify** from the router (no browser→ipify; still router→ipify). **Browser** mode unchanged (ipify + optional ipwho.is); strip text explains trade-offs; JS escapes `& < > "` for injected HTML.

4. **CSRF / session**  
   - Standard LuCI POST forms rely on session cookie and admin trust model; stock **`test_post_security`** compares **`formvalue("token")`** to **`context.authtoken`**.  
   - **Recommendation:** Use the same hidden-field **`token`** on custom forms; keep state-changing handlers on **POST** only.  
   - **Status (v1.2.17+):** **`luci.glinet_privacy.csrf`** + **`csrf_field.htm`** on **Overview**, **Kill switch**, **IMEI**, **Tor/DNS** forms; handlers require **`REQUEST_METHOD == POST`** before **`csrf.verify_post()`**. **`verify_ip`** remains GET JSON (session cookie only; not a form POST).

### Lower priority

5. **XSS residual surface**  
   - Translated strings and `it.detail` / badge hints rendered with `<%= %>` in places — LuCI `translate` output is usually safe, but any future dynamic HTML in details should use `pcdata()`.  
   - Verify: prefer `textContent` for dynamic bits where possible (already used for badge text in JS).  
   - **Status:** Implemented for **Overview** component rows — **`it.detail`** rendered with **`pcdata()`**. Verify page uses **`esc()`** before `innerHTML`.

---

## OpenWrt contributor / packaging perspective

| Topic | Current state | Upstream expectation |
|-------|---------------|----------------------|
| **Package layout** | Install via `install.sh` copying sources | Feed package: `Makefile` with `PKG_NAME`, `PKG_LICENSE`, `PKG_MAINTAINER`, **SPDX** file headers, split `luci-app-*` vs `glinet-privacy` **core** packages |
| **LuCI controller style** | Lua `module("…", package.seeall)` + optional **`menu.d` JSON** | Installer auto when **`openwrt_release`** ≥ **22.03** **or** stock **`menu.d/*.json`** exists (GL.iNet **`DISTRIB_RELEASE`** may be **4.x**). Marker **`luci-use-menu-d`** → Lua **`index()`** skipped. Actions stay Lua **`call()`** until a full ucode/JS port. |
| **Menu path** | `admin/services/glinet_privacy` | Acceptable; ensure no collision with core `services` naming |
| **Route alias** | `plugins` used for Tor/DNS page | Confusing for contributors — consider renaming internal route to `tor_dns` with redirect from old URL |
| **i18n** | Custom `luci.glinet_privacy.i18n` + POT | Prefer integration with **standard LuCI lmo** workflow and **Weblate** if targeting upstream |
| **Dependencies** | Declared implicitly in `install.sh` / opkg calls | `DEPENDS` in Makefile: `luci-base`, firewall, optional `tor`, etc. |
| **Tests** | None visible in repo | Shell: `shellcheck`; Lua: minimal unit tests for validators; optional CI |

---

## Best practices / maintainability

1. **Single source for “is watchdog dropping?”** — Today: `iptables` greps in Lua mirror shell. Extract a tiny **shared probe** (lua require or one `sh -c` script) and use **nft** fallback when `iptables` is absent.  
2. **Centralize validators** — *Done for input hardening:* **`luci/glinet_privacy/sanitize.lua`** (ifnames, modem tty, IPv4, CIDR, ports) shared by **`glinet_privacy.lua`** and **`net_probe.lua`**.  
3. **Privilege documentation** — README section: what runs as root, what UCI keys are written, what external URLs are contacted.  
4. **Error handling** — `sys.call` failures are often ignored (`>/dev/null`); consider surfaced **logread** hints on Overview for last apply failure (backlog).

---

## Feature backlog

Items are ordered by **priority band** (P0 → P3). **Themes** under each band group related work without changing the severity of the band. **Epic-style** delivery items (cellular, Tor, kill switch, telemetry) are tracked in **`docs/backlog.md`**; the list below is **contributor / security / OOTB** oriented and should stay in sync when priorities shift.

### P0 — Critical

*Security, correctness, and trustworthy status on the user’s firmware.*

#### Shell & ACL hardening

- [x] **Validate `wg_if`, `lan_dev`, `wan_dev`, `wwan_if`, Tor `lan_dev`** (and related POST fields: **modem tty**, **LAN CIDR**, **router LAN IP**, **Tor ports**) before shell/UCI use — see **`sanitize.lua`** (v1.2.13+).  
- [x] **Narrow rpcd ACL** — write **`privacy`**, **`rotate_imei`**, **`glinet_privacy`**, **`glvpn`** only; read retains **`network`**, **`firewall`**, **`dhcp`** for probes; description in JSON.

#### Firewall stack fidelity

- [ ] **nft coexistence:** extend status checks (Overview + Tor badge) when `iptables-nft` or raw **`nft`** is the only path.

---

### P1 — High

*Operator trust, transparency in LuCI, and composition with **GL.iNet stock** (OOTB). Use vendor UI for primary VPN/DNS configuration; this app explains coexistence and deep-links.*

#### In-app UX & transparency

- [x] **Verify — router-side quick IP** — authenticated **`verify_ip`** `call()` (router → **api.ipify.org** via `uclient-fetch` / `wget` / `curl`); LuCI **Router WAN** vs **Browser** mode; browser path still optional **ipwho.is** geo; strip text explains trade-offs. *Remaining:* true **“no external requests”** mode (fully offline / LAN-only).  
- [ ] **Overview:** link or tooltip to **last script exit** / `logread -e privacy` (or equivalent) excerpt.  
- [ ] **Kill switch:** show **effective** `_lan` / `_wan` the watchdog will use (same algorithm as `privacy-killswitch-watchdog.sh`) beside the live **`net_probe`** strip (today: detected path; watchdog-specific `_lan`/`_wan` resolution not duplicated in UI).

#### GL.iNet OOTB — privacy checkpoints & handoff

- [ ] **Privacy checkpoint panel** (Overview or strip): read-only checklist — this package (**Tor**, **telemetry off**, **watchdog**, **Verify**) **plus** stock expectations (*VPN Dashboard* kill switch **or** glinet-privacy watchdog; **Network → DNS** vs **Tor DNS forward**; external leak tests). Link `docs/devices.md` and GL.iNet docs.  
- [ ] **Network → DNS coexistence:** when **`dns_policy=tor_dnsmasq`** or blocklist applies, **detect** stock Encrypted DNS / manual DNS markers (per firmware family; document findings). Non-destructive warning + [DNS docs](https://docs.gl-inet.com/router/en/4/interface_guide/dns/); optional **compatibility matrix** (Tor DNS vs DoH, etc.).  
- [ ] **VPN Dashboard handoff:** static/dynamic **“configure in stock UI”** on **Kill switch** / **Overview** (Global vs **Policy**, **wgclient** vs **`wg0`**). **Read-only** tunnel/policy status via **`ifstatus`**, **`ubus`**, or **documented** vendor UCI only.  
- [ ] **Secure DNS + VPN precedence:** document and surface how stock toggles (**override DNS for all clients**, custom vs VPN DNS) interact with **`apply-dns-policy.sh`**.  
- [ ] **Stock privacy / security toggles** in checklist: DNS rebinding, GoodCloud/remote access, model-specific items (e.g. LED), as read-only hints.  
- [ ] **Applications layer:** if **AdGuard Home** / **DNS Proxy** detected, one line + link to stock **Applications** (image-dependent).  
- [ ] **Firmware-version matrix:** `docs/glinet-firmware-notes.md` or `devices.md` section for **v4.7 vs v4.8+** (multi-VPN, **nft**, dashboard changes); feed LuCI copy from it.

---

### P2 — Medium

*Upstream packaging and long-term maintainability of the codebase.*

#### Packaging & license

- [ ] Add **OpenWrt-style `Makefile`** packages (core + `luci-app-*`).  
- [ ] **SPDX** headers on new/changed files; **`PKG_LICENSE`**.

#### LuCI / routing hygiene

- [ ] Rename route **`plugins` → `tor_dns`** (+ compatibility alias).  
- [x] Migrate controller toward **ucode** when minimum OpenWrt version allows — **`menu.d`** tree on **OpenWrt 22.03+** (see `install.sh` **`install_luci_menu_json`** / **`GLINET_PRIVACY_LUCI_MENU_JSON`**); Lua **`call()`** handlers unchanged.

---

### P3 — Lower

*Enhancements that are useful but not blocking.*

#### Runtime diagnostics (read-only)

- [x] **WireGuard / OpenVPN** — **`vpn_probe.lua`** + Overview **WireGuard** row detail: **`ifstatus`** / **`ubus`** for **`wg_if`** and **`network`** **`proto`** `wireguard` / `openvpn`; **up** prefers ubus when present, else **`ip link`**.  
- [x] **IMEI** page: `mmcli` / `uqmi` hints when packages exist.

#### Quality & vendor APIs

- [ ] **CI:** `shellcheck`, lua static checks, mock UCI fixtures.  
- [x] **GL.iNet:** optional **`ubus` / `rpcd`** wrappers for VPN/DNS UI state (read-only, version-gated) only when documented (e.g. GSDK / vendor docs) — **`vendor_ubus.lua`**, **`docs/vendor-ubus.md`**, LuCI card (**Overview** / **Kill switch** / **Tor, DNS**); opt-in UCI **`glinet_privacy.vendor_ubus`**; no new rpcd plugins (server-side **`ubus`**, whitelist only).

#### Security / hygiene (ongoing)

- [x] **Overview dynamic detail** — **`pcdata(it.detail)`**; **Verify** dynamic HTML via **`esc()`**.  
- [x] **CSRF tokens** on custom POST forms — **`csrf.lua`** / **`csrf_field.htm`**; session **`authtoken`** as **`token`** (see Security findings §4).

---

## Conclusion

The implementation is **appropriate for a vendor-targeted privacy bundle** and shows good structure between LuCI and shell. **P0 shell/ACL hardening** and **partial Verify third-party mitigation** landed in **v1.2.13**; **custom-form CSRF** (**authtoken**) in **v1.2.17**; **nft coexistence** and **GL.iNet OOTB** checklist work remain the largest follow-ups. **GL.iNet OOTB** value is highest when this app **orchestrates and explains** stock **VPN Dashboard**, **Network → DNS** / **Encrypted DNS**, and **privacy checkpoints** instead of silently overlapping them. For **upstream contribution**, **Makefile split**, **SPDX**, and **nft-aware status** are the main structural follow-ups.

*Document version: 2026-04-09 — aligned with **`docs/backlog.md`** and `GLINET_PRIVACY_VERSION` **1.2.18** (`package/version.mk`). Re-check **`changes.md`** on each release.*
