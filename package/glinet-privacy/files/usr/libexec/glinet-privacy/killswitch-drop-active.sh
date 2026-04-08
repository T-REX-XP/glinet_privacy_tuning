#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 GL.iNet Privacy contributors
#
# Exit 0 if an emergency kill-switch DROP rule is present (same marker as
# privacy-killswitch-watchdog.sh). Single source for "is watchdog dropping?"
# — used by LuCI via firewall_status.lua; keep in sync with KS_COMMENT there.
#
# Probes: iptables listing, iptables-save (xtables-nft), nft ruleset (nft-only).

KS_COMMENT="privacy-killswitch-drop"

iptables -L FORWARD -n 2>/dev/null | grep -qF "$KS_COMMENT" && exit 0
iptables-save 2>/dev/null | grep -qF "$KS_COMMENT" && exit 0
nft list ruleset 2>/dev/null | grep -qF "$KS_COMMENT" && exit 0
exit 1
