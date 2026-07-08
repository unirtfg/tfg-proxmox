#!/usr/bin/env bash
# Cambia la contraseña 'admin' del indexer de Wazuh (single-node).
# Ejecutar EN la VM de monitorización (192.168.2.102). Uso: ./41-wazuh-change-password.sh 'NUEVA_PASS'
set -euo pipefail
NEW="${1:?Indica la nueva contraseña}"
DIR=/opt/stacks/wazuh-docker/single-node
IDX=single-node-wazuh.indexer-1
F=/usr/share/wazuh-indexer/config/opensearch-security/internal_users.yml

echo "==> Generar hash bcrypt"
HASH=$(sudo docker exec "$IDX" bash -c \
  "JAVA_HOME=/usr/share/wazuh-indexer/jdk bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p '$NEW'" \
  2>/dev/null | grep -E '^\$2[aby]\$' | tail -1)
[ -n "$HASH" ] || { echo "No se generó hash"; exit 1; }

echo "==> Editar internal_users.yml PRESERVANDO EL INODO (el bind-mount de fichero se rompe con sed -i)"
sudo docker exec "$IDX" bash -c \
  "sed '/^admin:/,/^  hash:/ s|hash: \"[^\"]*\"|hash: \"$HASH\"|' $F > /tmp/iu.yml && cat /tmp/iu.yml > $F"

echo "==> Aplicar con securityadmin"
sudo docker exec "$IDX" bash -c '
export JAVA_HOME=/usr/share/wazuh-indexer/jdk
/usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
 -f '"$F"' -t internalusers -icl -nhnv \
 -cacert /usr/share/wazuh-indexer/config/certs/root-ca.pem \
 -cert /usr/share/wazuh-indexer/config/certs/admin.pem \
 -key /usr/share/wazuh-indexer/config/certs/admin-key.pem \
 -h 127.0.0.1 -p 9200' | grep -iE 'SUCC|Done'

echo "==> Sincronizar fichero del host y propagar a manager/dashboard"
sudo docker exec "$IDX" cat "$F" | sudo tee "$DIR/config/wazuh_indexer/internal_users.yml" >/dev/null
sudo sed -i "s|INDEXER_PASSWORD=SecretPassword|INDEXER_PASSWORD=$NEW|g" "$DIR/docker-compose.yml"
cd "$DIR" && sudo docker compose up -d wazuh.manager wazuh.dashboard
echo "Hecho. Nuevo login del dashboard: admin / $NEW"
