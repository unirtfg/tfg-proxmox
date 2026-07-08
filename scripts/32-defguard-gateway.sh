#!/usr/bin/env bash
# Levanta el gateway WireGuard de Defguard en la VM de seguridad.
# Ejecutar EN la VM 192.168.2.100. Requiere DEFGUARD_TOKEN (de la Location creada en la web).
set -euo pipefail
: "${DEFGUARD_TOKEN:?Pega el token de la Location de Defguard}"
DIR=/opt/stacks/defguard

# 1) ip_forward + permitir wg0 en el FORWARD de Docker (persistente)
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-defguard.conf >/dev/null
sudo sysctl -p /etc/sysctl.d/99-defguard.conf
sudo iptables -C DOCKER-USER -i wg0 -j ACCEPT 2>/dev/null || sudo iptables -I DOCKER-USER -i wg0 -j ACCEPT
sudo iptables -C DOCKER-USER -o wg0 -j ACCEPT 2>/dev/null || sudo iptables -I DOCKER-USER -o wg0 -j ACCEPT
sudo tee /etc/systemd/system/defguard-forward.service >/dev/null <<'UNIT'
[Unit]
Description=Allow WireGuard wg0 forwarding through Docker FORWARD
After=docker.service
Requires=docker.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'iptables -C DOCKER-USER -i wg0 -j ACCEPT 2>/dev/null || iptables -I DOCKER-USER -i wg0 -j ACCEPT; iptables -C DOCKER-USER -o wg0 -j ACCEPT 2>/dev/null || iptables -I DOCKER-USER -o wg0 -j ACCEPT'
[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload && sudo systemctl enable --now defguard-forward.service

# 2) Compose del gateway
sudo tee "$DIR/gateway.compose.yaml" >/dev/null <<YAML
services:
  defguard-gateway:
    image: ghcr.io/defguard/gateway:1.6
    container_name: defguard-gateway
    restart: unless-stopped
    network_mode: host
    cap_add: [NET_ADMIN]
    environment:
      DEFGUARD_GRPC_URL: http://127.0.0.1:50055
      DEFGUARD_TOKEN: ${DEFGUARD_TOKEN}
      DEFGUARD_MASQUERADE: "true"
      RUST_LOG: info
YAML
cd "$DIR" && sudo docker compose -f gateway.compose.yaml up -d
sleep 6
sudo docker exec defguard-gateway wg show || true
