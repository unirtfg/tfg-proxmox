#!/usr/bin/env bash
# Configura Nginx Proxy Manager por API:
#   - Crea el primer usuario admin
#   - Emite el certificado wildcard *.${BASE_DOMAIN} por DNS-01 (DuckDNS)
#   - Crea los proxy hosts de todos los servicios (por IP interna)
#
# Variables: NPM_URL (http://192.168.2.100:81), NPM_EMAIL, NPM_PASS,
#            BASE_DOMAIN, DUCKDNS_TOKEN
set -euo pipefail
: "${NPM_URL:=http://192.168.2.100:81}"
: "${NPM_EMAIL:?}"; : "${NPM_PASS:?}"; : "${BASE_DOMAIN:?}"; : "${DUCKDNS_TOKEN:?}"
A="$NPM_URL/api"

echo "==> Crear primer usuario admin (si la BD está vacía)"
curl -s -X POST "$A/users" -H 'Content-Type: application/json' \
  --data-binary "{\"name\":\"Admin\",\"nickname\":\"Admin\",\"email\":\"$NPM_EMAIL\",\"roles\":[\"admin\"],\"is_disabled\":false,\"auth\":{\"type\":\"password\",\"secret\":\"$NPM_PASS\"}}" >/dev/null || true

TOKEN=$(curl -s -X POST "$A/tokens" -H 'Content-Type: application/json' \
  --data-binary "{\"identity\":\"$NPM_EMAIL\",\"secret\":\"$NPM_PASS\"}" | grep -oP '"token":"\K[^"]+')
[ -n "$TOKEN" ] || { echo "No se pudo autenticar en NPM"; exit 1; }
AH=(-H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json')

echo "==> Certificado wildcard *.$BASE_DOMAIN (DNS-01 DuckDNS)"
curl -s --max-time 280 -X POST "$A/nginx/certificates" "${AH[@]}" --data-binary "{
  \"provider\":\"letsencrypt\",
  \"domain_names\":[\"*.$BASE_DOMAIN\"],
  \"meta\":{\"dns_challenge\":true,\"dns_provider\":\"duckdns\",
            \"dns_provider_credentials\":\"dns_duckdns_token=$DUCKDNS_TOKEN\",
            \"propagation_seconds\":60}}" | grep -oE '"id":[0-9]+|"error".*' | head -1
CERT_ID=$(curl -s "$A/nginx/certificates" "${AH[@]}" | grep -oP '"id":\K[0-9]+' | head -1)
echo "   cert id=$CERT_ID"

echo "==> Proxy hosts"
# dominio  host_interno  puerto  esquema
HOSTS=(
  "npm.$BASE_DOMAIN 192.168.2.100 81 http"
  "auth.$BASE_DOMAIN 192.168.2.100 9000 http"
  "adguard.$BASE_DOMAIN 192.168.2.100 3000 http"
  "vpn.$BASE_DOMAIN 192.168.2.100 8000 http"
  "wazuh.$BASE_DOMAIN 192.168.2.102 443 https"
  "status.$BASE_DOMAIN 192.168.2.102 3001 http"
  "nextcloud.$BASE_DOMAIN 192.168.2.103 8081 http"
  "office.$BASE_DOMAIN 192.168.2.103 8082 http"
  "paperless.$BASE_DOMAIN 192.168.2.103 8000 http"
  "vault.$BASE_DOMAIN 192.168.2.103 8080 http"
)
for row in "${HOSTS[@]}"; do
  read -r dom host port scheme <<<"$row"
  curl -s -o /dev/null -X POST "$A/nginx/proxy-hosts" "${AH[@]}" --data-binary "{
    \"domain_names\":[\"$dom\"],\"forward_scheme\":\"$scheme\",\"forward_host\":\"$host\",
    \"forward_port\":$port,\"certificate_id\":$CERT_ID,\"ssl_forced\":true,\"http2_support\":true,
    \"block_exploits\":true,\"allow_websocket_upgrade\":true,\"caching_enabled\":false,
    \"locations\":[],\"meta\":{}}"
  echo "   + $dom -> $host:$port"
done
echo "Hecho."
