#!/usr/bin/env bash
set -euo pipefail

NAME="${1:-}"
WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_CONF="/etc/wireguard/$WG_INTERFACE.conf"
CLIENT_FILE="/etc/wireguard/clients/$NAME.conf"

if [[ $EUID -ne 0 ]]; then echo "Please run as root." >&2; exit 1; fi
if [[ -z "$NAME" || ! "$NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then echo "Usage: sudo bash scripts/remove-client.sh <client-name>" >&2; exit 1; fi
if [[ ! -f "$WG_CONF" ]]; then echo "WireGuard server is not installed." >&2; exit 1; fi
if [[ ! -f "$CLIENT_FILE" ]]; then echo "Client not found: $NAME" >&2; exit 1; fi

CLIENT_PUBLIC_KEY="$(awk -F' = ' '/^PublicKey/ {print $2; exit}' "$CLIENT_FILE" 2>/dev/null || true)"
# Client config contains the client's private key, not its public key. Derive it safely.
CLIENT_PRIVATE_KEY="$(awk -F' = ' '/^PrivateKey/ {print $2; exit}' "$CLIENT_FILE")"
CLIENT_PUBLIC_KEY="$(printf '%s' "$CLIENT_PRIVATE_KEY" | wg pubkey)"

TMP="$(mktemp)"
awk -v key="$CLIENT_PUBLIC_KEY" '
BEGIN { skip=0 }
/^\[Peer\]$/ {
  if (skip) { skip=0 }
  block=$0 ORS
  getline line
  while (line !~ /^$/ && !feof()) { block=block line ORS; if (line ~ /^PublicKey = /) pub=line; getline line }
  if (pub == "PublicKey = " key) { skip=1; next }
  printf "%s", block
  if (line == "") print ""
  next
}
{ if (!skip) print }
' "$WG_CONF" > "$TMP"
# The compact awk above is intentionally conservative; rebuild peer blocks using Python if available.
if command -v python3 >/dev/null 2>&1; then
python3 - "$WG_CONF" "$TMP" "$CLIENT_PUBLIC_KEY" <<'PY'
import sys
src, dst, key = sys.argv[1:]
text = open(src, encoding='utf-8').read()
blocks = text.split('\n[Peer]')
keep = [blocks[0]]
for block in blocks[1:]:
    if f'PublicKey = {key}' not in block:
        keep.append('[Peer]' + block)
open(dst, 'w', encoding='utf-8').write('\n[Peer]'.join(keep))
PY
fi
mv "$TMP" "$WG_CONF"
rm -f "$CLIENT_FILE"
chmod 600 "$WG_CONF"
wg syncconf "$WG_INTERFACE" <(wg-quick strip "$WG_INTERFACE")
echo "Client removed: $NAME"
