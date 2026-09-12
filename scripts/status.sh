#!/usr/bin/env bash
set -euo pipefail

WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/$WG_INTERFACE.conf"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash scripts/status.sh" >&2
  exit 1
fi

if [[ ! -f "$WG_CONF" ]]; then
  echo "WireGuard server is not installed: $WG_CONF" >&2
  exit 1
fi

printf '%s\n' "WireGuard Status" "────────────────────────────────────────"

if systemctl is-active --quiet "wg-quick@$WG_INTERFACE"; then
  echo "Service:      UP"
else
  echo "Service:      DOWN"
fi

echo "Interface:    $WG_INTERFACE"
echo "Listen:       $(wg show "$WG_INTERFACE" listen-port 2>/dev/null || echo unknown)/UDP"
echo "Public key:   $(wg show "$WG_INTERFACE" public-key 2>/dev/null || echo unknown)"

if command -v curl >/dev/null 2>&1; then
  PUBLIC_IP="$(curl -4fsS --max-time 5 https://api.ipify.org || true)"
  [[ -n "$PUBLIC_IP" ]] && echo "Public IPv4:  $PUBLIC_IP"
fi

printf '%s\n' "" "Peers"

if ! wg show "$WG_INTERFACE" peers >/dev/null 2>&1; then
  echo "No active WireGuard interface."
  exit 0
fi

printf '%-20s %-16s %-12s %-20s %s\n' "NAME" "VPN IP" "HANDSHAKE" "RX/TX" "PUBLIC KEY"

while IFS= read -r peer; do
  [[ -z "$peer" ]] && continue
  allowed="$(wg show "$WG_INTERFACE" allowed-ips | awk -v p="$peer" '$1 == p {print $2; exit}')"
  latest="$(wg show "$WG_INTERFACE" latest-handshakes | awk -v p="$peer" '$1 == p {print $2; exit}')"
  rx="$(wg show "$WG_INTERFACE" transfer | awk -v p="$peer" '$1 == p {print $2; exit}')"
  tx="$(wg show "$WG_INTERFACE" transfer | awk -v p="$peer" '$1 == p {print $3; exit}')"

  name="-"
  if [[ -n "$allowed" && -f "$WG_CONF" ]]; then
    name="$(awk -v ip="$allowed" '
      /^# client: / {name=$0; sub(/^# client: /, "", name)}
      $0 == "AllowedIPs = " ip {print name; exit}
    ' "$WG_CONF")"
    [[ -z "$name" ]] && name="-"
  fi

  if [[ -n "$latest" && "$latest" != "0" ]]; then
    now="$(date +%s)"
    age=$((now - latest))
    if (( age <= 180 )); then
      handshake="ONLINE"
    elif (( age <= 900 )); then
      handshake="RECENT"
    else
      handshake="OFFLINE"
    fi
  else
    handshake="NEVER"
  fi

  printf '%-20s %-16s %-12s %-20s %s\n' "$name" "$allowed" "$handshake" "${rx:-0}/${tx:-0}" "$peer"
done < <(wg show "$WG_INTERFACE" peers)

printf '%s\n' "" "Tip: run 'sudo wg show $WG_INTERFACE' for raw WireGuard details."
