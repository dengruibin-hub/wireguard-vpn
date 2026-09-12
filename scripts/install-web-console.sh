#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash scripts/install-web-console.sh" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/web-console"
VENV_DIR="/opt/wireguard-web-console"
SERVICE_FILE="/etc/systemd/system/wireguard-web-console.service"

apt-get update
apt-get install -y python3-venv

python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install -r "$APP_DIR/requirements.txt"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=WireGuard Web Console
After=network.target wg-quick@wg0.service
Wants=wg-quick@wg0.service

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
ExecStart=$VENV_DIR/bin/python $APP_DIR/app.py
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now wireguard-web-console.service

sleep 1
systemctl --no-pager --full status wireguard-web-console.service

echo
echo "Web Console is running on 127.0.0.1:8080"
echo "SSH tunnel: ssh -L 8080:127.0.0.1:8080 root@YOUR_VPS_IP"
