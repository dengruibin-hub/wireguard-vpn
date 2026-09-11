#!/usr/bin/env bash
set -euo pipefail

WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_PORT="${WG_PORT:-51820}"
WG_NETWORK="${WG_NETWORK:-10.66.66.0/24}"
WG_SERVER_ADDR="${WG_SERVER_ADDR:-10.66.66.1/24}"
WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/$WG_INTERFACE.conf"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash scripts/install-server.sh" >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This installer currently supports Debian/Ubuntu systems using apt." >&2
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard iptables

install -d -m 700 "$WG_DIR" "$WG_DIR/clients"

if [[ ! -f "$WG_DIR/server_private.key" ]]; then
  umask 077
  wg genkey | tee "$WG_DIR/server_private.key" | wg pubkey > "$WG_DIR/server_public.key"
fi

SERVER_PRIVATE_KEY="$(cat "$WG_DIR/server_private.key")"
DEFAULT_IFACE="$(ip route show default | awk 'NR==1 {print $5}')"
if [[ -z "$DEFAULT_IFACE" ]]; then
  echo "Unable to detect the default network interface." >&2
  exit 1
fi

if [[ ! -f "$WG_CONF" ]]; then
  cat > "$WG_CONF" <<EOF
[Interface]
Address = $WG_SERVER_ADDR
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -s $WG_NETWORK -o $DEFAULT_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -s $WG_NETWORK -o $DEFAULT_IFACE -j MASQUERADE
EOF
  chmod 600 "$WG_CONF"
fi

SYSCTL_FILE="/etc/sysctl.d/99-wireguard-vpn.conf"
cat > "$SYSCTL_FILE" <<EOF
net.ipv4.ip_forward=1
EOF
sysctl --system >/dev/null

systemctl enable --now "wg-quick@$WG_INTERFACE"

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow "$WG_PORT/udp"
fi

echo
 echo "WireGuard server is ready."
echo "Interface: $WG_INTERFACE"
echo "UDP port: $WG_PORT"
echo "VPN network: $WG_NETWORK"
echo "Next: sudo bash scripts/add-client.sh phone"
