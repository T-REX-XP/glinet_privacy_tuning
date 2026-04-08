Act as an expert OpenWrt embedded Linux developer and security engineer. I am building a privacy-first router using a GL.iNet Puli (GL-XE300) which runs OpenWrt and has a Quectel EG25-G 4G LTE module. 

I need to write ash (bash) scripts, uci configurations, and iptables/nftables rules to implement the following features. Keep in mind that OpenWrt uses standard POSIX shell (ash), not bash.

Please generate the necessary scripts and configuration steps for:

1.  **IMEI Rotation Script:** A script that generates a random but valid IMEI (starting with a known TAC or totally random with correct Luhn checksum) and sends the AT command (`AT+EGMR=1,7,"<NEW_IMEI>"`) to the Quectel EG25-G module (usually via `/dev/ttyUSB2` or `/dev/ttyUSB3`). It should restart the modem interface afterward. Provide instructions to run this on boot via `/etc/init.d/` and via cron every X hours.
2.  **Mullvad VPN via WireGuard:** CLI/uci commands to configure a WireGuard client connected to Mullvad. 
3.  **Transparent Tor Proxy:** Script/uci commands to install Tor, configure it as a transparent proxy for the LAN interface, and ensure all DNS requests are routed through Tor to prevent leaks.
4.  **Advanced Kill Switch:** iptables/nftables rules that drop ALL forward and output traffic from the LAN if the VPN interface (`wg0`) or Tor service drops. No clear-net traffic must ever leave the WAN interface directly.
5.  **Remove/Block GL.iNet Telemetry:** uci commands to disable "GoodCloud" and other GL.iNet background services, plus a dnsmasq or hosts configuration to black-hole GL.iNet tracking domains (e.g., `goodcloud.xyz`, `gldns.com`).

Structure the output logically: provide the exact scripts, file paths (e.g., `/etc/config/network`, `/usr/bin/rotate_imei.sh`), and the commands to apply them.