#!/usr/bin/env bash
set -euo pipefail

NAME="${1:-}"
WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_PORT="${WG_PORT:-51820}"
WG_SERVER_ADDR="${WG_SERVER_ADDR:-10.66.66.1/24}"
CLIENT_DIR="/etc/wireguard/clients"
WG_CONF="/etc/wireguard/$WG_INTERFACE.conf"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root." >&2
  exit 1
fi
if [[ -z "$NAME" || ! "$NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "Usage: sudo bash scripts/add-client.sh <client-name>" >&2
  exit 1
fi
if [[ ! -f "$WG_CONF" ]]; then
  echo "WireGuard server is not installed yet." >&2
  exit 1
fi
if [[ -f "$CLIENT_DIR/$NAME.conf" ]]; then
  echo "Client already exists: $NAME" >&2
  exit 1
fi

install -d -m 700 "$CLIENT_DIR"
SERVER_PUBLIC_KEY="$(cat /etc/wireguard/server_public.key)"
SERVER_ENDPOINT="${WG_ENDPOINT:-}"
if [[ -z "$SERVER_ENDPOINT" ]] && command -v curl >/dev/null 2>&1; then
  SERVER_ENDPOINT="$(curl -4fsS --max-time 5 https://api.ipify.org || true)"
fi
if [[ -z "$SERVER_ENDPOINT" ]]; then
  echo "Set WG_ENDPOINT to your VPS public IP or DNS name and rerun." >&2
  exit 1
fi

# Allocate the first unused address from 10.66.66.2-254.
for octet in $(seq 2 254); do
  ADDR="10.66.66.$octet"
  if ! grep -q "AllowedIPs = $ADDR/32" "$WG_CONF"; then
    break
  fi
done
if [[ "$octet" == "254" && -n "$(grep -F "AllowedIPs = 10.66.66.254/32" "$WG_CONF" || true)" ]]; then
  echo "No client IP addresses remain." >&2
  exit 1
fi

umask 077
PRIVATE_KEY="$(wg genkey)"
PUBLIC_KEY="$(printf '%s' "$PRIVATE_KEY" | wg pubkey)"
CLIENT_FILE="$CLIENT_DIR/$NAME.conf"

cat > "$CLIENT_FILE" <<EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $ADDR/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT:$WG_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

cat >> "$WG_CONF" <<EOF

# client: $NAME
[Peer]
PublicKey = $PUBLIC_KEY
AllowedIPs = $ADDR/32
EOF
chmod 600 "$CLIENT_FILE" "$WG_CONF"
wg syncconf "$WG_INTERFACE" <(wg-quick strip "$WG_INTERFACE")

echo "Client created: $NAME"
echo "Address: $ADDR"
echo "Config: $CLIENT_FILE"
echo "Import this file into the WireGuard client. Keep it secret."
