#!/usr/bin/env bash
# Integra OnlyOffice en Nextcloud (occ). Ejecutar EN la VM de productividad (192.168.2.103).
set -euo pipefail
: "${OO_JWT:?}"; : "${BASE_DOMAIN:?}"
occ() { sudo docker exec -u www-data nextcloud php occ "$@"; }

occ config:system:set allow_local_remote_servers --value true --type boolean
occ app:install onlyoffice 2>/dev/null || occ app:enable onlyoffice
occ config:app:set onlyoffice DocumentServerUrl --value "https://office.${BASE_DOMAIN}/"
occ config:app:set onlyoffice jwt_secret --value "${OO_JWT}"
occ config:app:set onlyoffice jwt_header --value "Authorization"
echo "OnlyOffice integrado. Verifica:"
sudo docker exec nextcloud sh -c "curl -s -o /dev/null -w 'NC->OO=%{http_code}\n' https://office.${BASE_DOMAIN}/healthcheck"
sudo docker exec onlyoffice sh -c "curl -s -o /dev/null -w 'OO->NC=%{http_code}\n' https://nextcloud.${BASE_DOMAIN}/status.php"
