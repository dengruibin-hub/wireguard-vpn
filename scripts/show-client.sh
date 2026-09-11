#!/usr/bin/env bash
set -euo pipefail

NAME="${1:-}"
CLIENT_DIR="/etc/wireguard/clients"
CLIENT_FILE="$CLIENT_DIR/$NAME.conf"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash scripts/show-client.sh <client-name>" >&2
  exit 1
fi
if [[ -z "$NAME" || ! "$NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "Usage: sudo bash scripts/show-client.sh <client-name>" >&2
  exit 1
fi
if [[ ! -f "$CLIENT_FILE" ]]; then
  echo "Client not found: $NAME" >&2
  exit 1
fi

cat "$CLIENT_FILE"

echo
if command -v qrencode >/dev/null 2>&1; then
  echo "QR code:"
  qrencode -t ANSIUTF8 < "$CLIENT_FILE"
else
  echo "Tip: install qrencode for a terminal QR code: apt-get install -y qrencode"
fi
