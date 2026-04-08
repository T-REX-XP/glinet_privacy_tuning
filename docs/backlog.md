# Privacy-First Router Project Backlog (GL-XE300 Puli, GL-AXT1800 Slate AX, …)

## Epic 1: Cellular Anonymity (EG25-G Module)
- [ ] Task 1.1: Write a shell script to generate a valid IMEI (implement Luhn algorithm for the last digit).
- [ ] Task 1.2: Implement function to send AT command (`AT+EGMR=1,7,"IMEI"`) to `/dev/ttyUSB2` or `/dev/ttyUSB3`.
- [ ] Task 1.3: Add a script to `/etc/init.d/` to run IMEI rotation on boot.
- [ ] Task 1.4: Add a cron job for time-based IMEI rotation.

## Epic 2: Secure Tunneling (VPN & Tor)
- [ ] Task 2.1: Configure OpenWrt WireGuard (`wg0`) using Mullvad configuration via `uci`.
- [ ] Task 2.2: Install and configure `tor` package.
- [ ] Task 2.3: Set up Tor Transparent Proxy (route all LAN TCP traffic through Tor network).
- [ ] Task 2.4: Ensure DNS requests are routed exclusively through Tor or Mullvad DNS.

## Epic 3: Hardened Kill Switch
- [ ] Task 3.1: Enable GL.iNet default VPN kill switch via `uci`.
- [ ] Task 3.2: Write custom `iptables` rules to completely block clear-net traffic if `wg0` is down.
- [ ] Task 3.3: Write an active monitoring script (watchdog) that checks Tor/VPN health and disables the LAN bridge if a failure is detected.

## Epic 4: De-bloating and Anti-Telemetry
- [ ] Task 4.1: Disable GoodCloud service via `uci`.
- [ ] Task 4.2: Disable remote support and tracking packages (e.g., `gl-cloud`, `gl-modem-tracking` if any).
- [ ] Task 4.3: Add GL.iNet telemetry domains to `/etc/hosts` or `dnsmasq` pointing to `0.0.0.0`.