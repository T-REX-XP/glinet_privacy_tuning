# GL.iNet Privacy — Contributor review

**Scope:** `luci-app-glinet-privacy`, `net_probe.lua`, controller actions, templates (`overview`, `killswitch`, `imei`, `tor_dns`, `verify`), `install.sh`, rpcd ACL.  
**Perspectives:** security hardening, OpenWrt packaging / upstream norms, maintainability / best practices.

---

## Executive summary

The LuCI surface is **coherent and user-oriented**: UCI-backed forms, shared styling, runtime probing for LAN/WAN/Tor hints, and scripts invoked via **fixed paths** (good). Main gaps for an upstream-quality package are: **shell command construction from UCI strings** (command injection class), **rpcd ACL broader than proven need**, **iptables-centric health checks** on **nft-first** systems, **legacy LuCI Lua patterns** (`module()`, `package.seeall`), **no in-tree OpenWrt `Makefile` feed layout**, and **third-party network calls** from the **Verify** tab admin session.

---

## Strengths (keep doing this)

| Area | Observation |
|------|-------------|
| **Separation of concerns** | Firewall / watchdog logic lives in shell under `/usr/libexec` and `/usr/bin`; LuCI mostly edits UCI and triggers apply — easier to audit than embedding `iptables` in pages. |
| **UCI as contract** | `privacy`, `glinet_privacy`, `rotate_imei` are clear configuration boundaries; templates align with apply scripts. |
| **Input narrowing (partial)** | `vendor_gl_vpn_killswitch` restricted to `on`/`off`/`leave`; IMEI TAC digits stripped and length-capped. |
| **Template escaping** | Dynamic interface names use `pcdata()` in several views; Verify JS escapes `<`/`>` before `innerHTML`. |
| **Runtime hints** | `net_probe.lua` uses kernel **`ip`** output and UCI — appropriate for OpenWrt. |
| **External links** | Verify / tools use `rel="noopener noreferrer"` where applicable. |

---

## Security findings

### High priority

1. **Command injection via UCI-sourced strings in shell one-liners**  
   - **Controller:** `build_status()` runs `ip link show " .. wg_if .. "` — `wg_if` comes from UCI (`privacy.main.wg_if`). A value containing shell metacharacters could alter the command (admin-only, still violates defense-in-depth).  
   - **`net_probe.lua`:** `ip … show dev " .. dev` — `dev` is derived from UCI / composed LAN name; same class of issue.  
   - **Recommendation:** Validate against a strict pattern (e.g. Linux iface: `^[a-zA-Z0-9._-]+$`, length cap ~15–32) before any `sys.call` / `sys.exec` that interpolates the value; reject or strip invalid input on **save** and **before probes**.

2. **rpcd ACL grants wide UCI write** (`luci-app-glinet-privacy.json`)  
   - **Write** access includes **`network`**, **`firewall`**, **`dhcp`** in addition to `privacy` / `glinet_privacy` / `rotate_imei` / `glvpn`.  
   - If this ACL is attached to roles beyond the intended admin surface, impact is large.  
   - **Recommendation:** Restrict to the packages this app actually **commits**; add **read-only** where sufficient (e.g. `network` read for probes if your stack enforces ACL on UBI). Document why each stanza is needed.

### Medium priority

3. **Verify tab: third-party endpoints**  
   - Browser `fetch()` to **api.ipify.org** and **ipwho.is** from a logged-in LuCI session leaks **client public IP** to those operators and depends on their **availability / CORS / trust**.  
   - **Recommendation:** Document in UI copy; optionally proxy via router (uhttpd/cgi — higher effort) or offer “offline / no external check” mode; consider **Content-Security-Policy** implications if LuCI tightens CSP globally.

4. **CSRF / session**  
   - Standard LuCI POST forms rely on session cookie and admin trust model.  
   - **Recommendation:** Align with target LuCI major version (ucode/JS) and any **anti-CSRF** helpers if upstream requires them for new apps.

### Lower priority

5. **XSS residual surface**  
   - Translated strings and `it.detail` / badge hints rendered with `<%= %>` in places — LuCI `translate` output is usually safe, but any future dynamic HTML in details should use `pcdata()`.  
   - Verify: prefer `textContent` for dynamic bits where possible (already used for badge text in JS).

---

## OpenWrt contributor / packaging perspective

| Topic | Current state | Upstream expectation |
|-------|---------------|----------------------|
| **Package layout** | Install via `install.sh` copying sources | Feed package: `Makefile` with `PKG_NAME`, `PKG_LICENSE`, `PKG_MAINTAINER`, **SPDX** file headers, split `luci-app-*` vs `glinet-privacy` **core** packages |
| **LuCI controller style** | Lua `module("…", package.seeall)` | Moving toward **ucode / JavaScript** controllers in modern OpenWrt LuCI; Lua still accepted in many feeds but is legacy |
| **Menu path** | `admin/services/glinet_privacy` | Acceptable; ensure no collision with core `services` naming |
| **Route alias** | `plugins` used for Tor/DNS page | Confusing for contributors — consider renaming internal route to `tor_dns` with redirect from old URL |
| **i18n** | Custom `luci.glinet_privacy.i18n` + POT | Prefer integration with **standard LuCI lmo** workflow and **Weblate** if targeting upstream |
| **Dependencies** | Declared implicitly in `install.sh` / opkg calls | `DEPENDS` in Makefile: `luci-base`, firewall, optional `tor`, etc. |
| **Tests** | None visible in repo | Shell: `shellcheck`; Lua: minimal unit tests for validators; optional CI |

---

## Best practices / maintainability

1. **Single source for “is watchdog dropping?”** — Today: `iptables` greps in Lua mirror shell. Extract a tiny **shared probe** (lua require or one `sh -c` script) and use **nft** fallback when `iptables` is absent.  
2. **Centralize validators** — `sanitize_ifname()`, `sanitize_port()`, CIDR parser shared between controller + `net_probe`.  
3. **Privilege documentation** — README section: what runs as root, what UCI keys are written, what external URLs are contacted.  
4. **Error handling** — `sys.call` failures are often ignored (`>/dev/null`); consider surfaced **logread** hints on Overview for last apply failure (backlog).

---

## Feature backlog (prioritized)

### P0 — Hardening / correctness

- [ ] **Validate `wg_if`, `lan_dev`, `wan_dev`, `wwan_if`, Tor `lan_dev`** before shell/OS use (regex + length).  
- [ ] **Narrow rpcd ACL** to minimal UCI read/write; document exceptions.  
- [ ] **nft coexistence:** extend status checks (Overview + Tor badge) when `iptables-nft` or raw `nft` is the only path.

### P1 — UX / transparency

- [ ] **Verify:** toggle “no third-party requests”; show router-side `curl`-based optional check (busybox) with user consent.  
- [ ] **Overview:** link or tooltip to **last script exit** / `logread -e privacy` excerpt.  
- [ ] **Kill switch:** show **effective** `_lan` / `_wan` the watchdog will use (same algorithm as `privacy-killswitch-watchdog.sh`) inline with probe.

### P2 — Upstream readiness

- [ ] Add **OpenWrt-style `Makefile`** packages (core + `luci-app-*`).  
- [ ] **SPDX** headers on new/changed files; `PKG_LICENSE`.  
- [ ] Rename route **`plugins` → `tor_dns`** (+ compatibility alias).  
- [ ] Migrate controller toward **ucode** when minimum OpenWrt version is bumped.

### P3 — Nice-to-have

- [ ] **WireGuard / OpenVPN** detection row using `ifstatus` / ubus where available.  
- [ ] **IMEI** page: show `mmcli` / `uqmi`-derived state when packages exist (read-only).  
- [ ] **Automated tests** in CI (`shellcheck`, lua static check, mock UCI fixtures).

---

## Conclusion

The implementation is **appropriate for a vendor-targeted privacy bundle** and shows good structure between LuCI and shell. For **security best practices**, **ifname sanitization** and **ACL scoping** are the first fixes an OpenWrt-minded reviewer would ask for; for **upstream contribution**, **Makefile split**, **SPDX**, and **nft-aware status** are the main structural follow-ups.

*Document version: 2026-04-08 (repo state `GLINET_PRIVACY_VERSION` in `package/version.mk`).*
