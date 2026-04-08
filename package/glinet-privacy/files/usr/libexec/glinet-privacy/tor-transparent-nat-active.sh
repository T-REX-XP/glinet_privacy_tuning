#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# Exit 0 if Tor transparent NAT / DNS redirect looks present (iptables or nft).
# Args: [trans_port] [dns_port] — defaults 9040 9053 (must be decimal 1–65535).
# Single source for LuCI firewall_status.lua; logic must stay aligned.

TP="${1:-9040}"
DP="${2:-9053}"

case "$TP" in '' | *[!0-9]*) TP=9040 ;; esac
case "$DP" in '' | *[!0-9]*) DP=9053 ;; esac
[ "$TP" -ge 1 ] 2>/dev/null && [ "$TP" -le 65535 ] 2>/dev/null || TP=9040
[ "$DP" -ge 1 ] 2>/dev/null && [ "$DP" -le 65535 ] 2>/dev/null || DP=9053

iptables -t nat -L PREROUTING -n 2>/dev/null | grep -q REDIRECT && exit 0
iptables-save -t nat 2>/dev/null | grep -qi REDIRECT && exit 0

_nft=$(nft list ruleset 2>/dev/null) || _nft=""
[ -z "$_nft" ] && exit 1

_low=$(printf '%s' "$_nft" | tr '[:upper:]' '[:lower:]')
echo "$_low" | grep -qE 'redirect|dnat' || exit 1

printf '%s' "$_nft" | grep -q "$TP" && exit 0
printf '%s' "$_nft" | grep -q "$DP" && exit 0
echo "$_low" | grep -q ":${TP}" && exit 0
echo "$_low" | grep -q ":${DP}" && exit 0
exit 1
