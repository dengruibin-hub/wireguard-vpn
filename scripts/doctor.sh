#!/usr/bin/env bash
set -euo pipefail

WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_PORT="${WG_PORT:-51820}"
WG_SUBNET="${WG_SUBNET:-10.66.66.0/24}"
WG_CONF="/etc/wireguard/$WG_INTERFACE.conf"

ok=0
fail=0

pass() { printf '[ OK ] %s\n' "$1"; ok=$((ok + 1)); }
warn() { printf '[WARN] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; fail=$((fail + 1)); }

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root." >&2
  exit 1
fi

if command -v wg >/dev/null 2>&1; then pass "wg command installed"; else fail "wg command not found"; fi
if command -v wg-quick >/dev/null 2>&1; then pass "wg-quick installed"; else fail "wg-quick not found"; fi
if [[ -f "$WG_CONF" ]]; then pass "server config exists: $WG_CONF"; else fail "server config missing: $WG_CONF"; fi

if systemctl is-enabled --quiet "wg-quick@$WG_INTERFACE" 2>/dev/null; then
  pass "WireGuard service enabled at boot"
else
  warn "WireGuard service is not enabled at boot"
fi

if systemctl is-active --quiet "wg-quick@$WG_INTERFACE" 2>/dev/null; then
  pass "WireGuard service is active"
else
  fail "WireGuard service is not active"
fi

if ip link show "$WG_INTERFACE" >/dev/null 2>&1; then
  pass "interface $WG_INTERFACE exists"
else
  fail "interface $WG_INTERFACE does not exist"
fi

if [[ -r /proc/sys/net/ipv4/ip_forward ]] && [[ "$(cat /proc/sys/net/ipv4/ip_forward)" == "1" ]]; then
  pass "IPv4 forwarding enabled"
else
  fail "IPv4 forwarding is disabled"
fi

if command -v ss >/dev/null 2>&1 && ss -lun | awk '{print $5}' | grep -Eq "[:.]$WG_PORT$"; then
  pass "UDP port $WG_PORT is listening"
else
  warn "Could not confirm UDP port $WG_PORT is listening"
fi

if command -v iptables >/dev/null 2>&1; then
  if iptables -t nat -S POSTROUTING 2>/dev/null | grep -Fq -- "-s $WG_SUBNET"; then
    pass "NAT rule for $WG_SUBNET exists"
  else
    fail "NAT rule for $WG_SUBNET was not found"
  fi
else
  fail "iptables command not found"
fi

if command -v wg >/dev/null 2>&1 && ip link show "$WG_INTERFACE" >/dev/null 2>&1; then
  peer_count="$(wg show "$WG_INTERFACE" peers 2>/dev/null | wc -l | tr -d ' ')"
  pass "WireGuard peers: $peer_count"
fi

echo
echo "Doctor summary: $ok checks passed, $fail checks failed."
if (( fail > 0 )); then
  exit 1
fi
