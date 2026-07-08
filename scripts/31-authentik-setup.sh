#!/usr/bin/env bash
# Configura Authentik por API: proveedores OIDC para Nextcloud y Paperless, grupo
# "empresa" y bindings de acceso. Imprime client_id/secret y el JSON PL_OIDC_PROVIDERS.
#
# Variables: AK_URL (http://192.168.2.100:9000), AK_TOKEN (token API de akadmin), BASE_DOMAIN
set -euo pipefail
: "${AK_URL:=http://192.168.2.100:9000}"; : "${AK_TOKEN:?}"; : "${BASE_DOMAIN:?}"
A="$AK_URL/api/v3"; H=(-H "Authorization: Bearer $AK_TOKEN" -H "Content-Type: application/json")
rnd() { tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$1"; }
get_pk() { curl -s "${H[@]}" "$A/$1" | grep -oE '"pk":"[^"]*"' | head -1 | cut -d'"' -f4; }

AUTHZ=$(get_pk "flows/instances/?slug=default-provider-authorization-explicit-consent")
INVAL=$(get_pk "flows/instances/?slug=default-provider-invalidation-flow")
KEY=$(curl -s "${H[@]}" "$A/crypto/certificatekeypairs/?has_key=true" | grep -oE '"pk":"[^"]*"' | head -1 | cut -d'"' -f4)
SC_OPENID=$(curl -s "${H[@]}" "$A/propertymappings/provider/scope/" | grep -B2 '"scope_name":"openid"'  | grep -oE '"pk":"[^"]*"' | head -1 | cut -d'"' -f4)
SC_EMAIL=$(curl  -s "${H[@]}" "$A/propertymappings/provider/scope/" | grep -B2 '"scope_name":"email"'   | grep -oE '"pk":"[^"]*"' | head -1 | cut -d'"' -f4)
SC_PROF=$(curl   -s "${H[@]}" "$A/propertymappings/provider/scope/" | grep -B2 '"scope_name":"profile"' | grep -oE '"pk":"[^"]*"' | head -1 | cut -d'"' -f4)

make_oidc() { # $1=Nombre  $2=slug  $3=redirect_uri  -> exporta CID/CSEC
  CID=$(rnd 40); CSEC=$(rnd 64)
  local pk
  pk=$(curl -s "${H[@]}" -X POST "$A/providers/oauth2/" --data-binary "{
    \"name\":\"$1\",\"authorization_flow\":\"$AUTHZ\",\"invalidation_flow\":\"$INVAL\",
    \"client_type\":\"confidential\",\"client_id\":\"$CID\",\"client_secret\":\"$CSEC\",
    \"redirect_uris\":[{\"matching_mode\":\"strict\",\"url\":\"$3\"}],
    \"signing_key\":\"$KEY\",\"sub_mode\":\"hashed_user_id\",
    \"property_mappings\":[\"$SC_OPENID\",\"$SC_EMAIL\",\"$SC_PROF\"]}" | grep -oE '"pk":[0-9]+' | head -1 | cut -d: -f2)
  curl -s -o /dev/null "${H[@]}" -X POST "$A/core/applications/" \
    --data-binary "{\"name\":\"$1\",\"slug\":\"$2\",\"provider\":$pk}"
  echo "$1: client_id=$CID  client_secret=$CSEC"
}

echo "==> Proveedor OIDC Nextcloud"
make_oidc "Nextcloud" "nextcloud" "https://nextcloud.$BASE_DOMAIN/apps/user_oidc/code"
echo "==> Proveedor OIDC Paperless"
make_oidc "Paperless" "paperless" "https://paperless.$BASE_DOMAIN/accounts/oidc/authentik/login/callback/"
PL_CID=$CID; PL_CSEC=$CSEC

echo "==> Grupo 'empresa' + bindings de acceso"
GRP=$(curl -s "${H[@]}" -X POST "$A/core/groups/" --data-binary '{"name":"empresa"}' | grep -oE '"pk":"[^"]*"' | head -1 | cut -d'"' -f4)
for slug in nextcloud paperless; do
  APP=$(get_pk "core/applications/$slug/")
  curl -s -o /dev/null "${H[@]}" -X POST "$A/policies/bindings/" \
    --data-binary "{\"target\":\"$APP\",\"group\":\"$GRP\",\"order\":0,\"enabled\":true}"
done

echo
echo "==> Para el .env de Paperless (PL_OIDC_PROVIDERS):"
echo "PL_OIDC_PROVIDERS={\"openid_connect\":{\"APPS\":[{\"provider_id\":\"authentik\",\"name\":\"Authentik\",\"client_id\":\"$PL_CID\",\"secret\":\"$PL_CSEC\",\"settings\":{\"server_url\":\"https://auth.$BASE_DOMAIN/application/o/paperless/.well-known/openid-configuration\"}}]}}"
echo
echo "Recuerda en Nextcloud (occ): app:install user_oidc + user_oidc:provider Authentik --clientid=.. --clientsecret=.. --discoveryuri=https://auth.$BASE_DOMAIN/application/o/nextcloud/.well-known/openid-configuration --mapping-uid=preferred_username --unique-uid=0"
