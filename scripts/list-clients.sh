#!/usr/bin/env bash
set -euo pipefail

WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_CONF="/etc/wireguard/$WG_INTERFACE.conf"
CLIENT_DIR="/etc/wireguard/clients"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root." >&2
  exit 1
fi
if [[ ! -f "$WG_CONF" ]]; then
  echo "WireGuard server is not installed yet." >&2
  exit 1
fi

if ! command -v wg >/dev/null 2>&1; then
  echo "WireGuard is not installed." >&2
  exit 1
fi

printf '%-20s %-15s %-44s %-12s %s\n' "CLIENT" "ADDRESS" "PUBLIC KEY" "STATUS" "LAST HANDSHAKE"
printf '%-20s %-15s %-44s %-12s %s\n' "--------------------" "---------------" "--------------------------------------------" "------------" "--------------"

if [[ ! -d "$CLIENT_DIR" ]]; then
  echo "No clients found."
  exit 0
fi

found=0
while IFS= read -r file; do
  found=1
  name="$(basename "$file" .conf)"
  address="$(awk -F' = ' '/^Address = / {print $2; exit}' "$file" | cut -d/ -f1)"
  public_key="$(awk -F' = ' '/^PublicKey = / {print $2; exit}' "$file")"
  handshake=""
  if [[ -n "$public_key" ]]; then
    handshake="$(wg show "$WG_INTERFACE" latest-handshakes | awk -v key="$public_key" '$1 == key {print $2}')"
  fi

  status="NEVER"
  last="never"
  if [[ -n "$handshake" && "$handshake" != "0" ]]; then
    now="$(date +%s)"
    age=$((now - handshake))
    last="${age}s ago"
    if (( age <= 180 )); then
      status="ONLINE"
    elif (( age <= 900 )); then
      status="RECENT"
    else
      status="OFFLINE"
    fi
  fi

  printf '%-20s %-15s %-44s %-12s %s\n' "$name" "${address:-unknown}" "${public_key:-unknown}" "$status" "$last"
done < <(find "$CLIENT_DIR" -maxdepth 1 -type f -name '*.conf' -print | sort)

if (( found == 0 )); then
  echo "No clients found."
fi
