#!/usr/bin/env bash
# Inserta los monitores en Uptime Kuma directamente en su SQLite.
# Ejecutar EN la VM de monitorización (192.168.2.102). Alternativa: importar
# stacks/uptimekuma/monitors.json desde Settings -> Backup -> Import.
set -euo pipefail
DATA=/opt/stacks/uptimekuma/data
SQL=$(cat <<'EOSQL'
INSERT INTO monitor (user_id,name,type,active,interval,retry_interval,maxretries,timeout,url,accepted_statuscodes_json) VALUES
(1,'Nginx Proxy Manager','http',1,60,60,2,30,'http://192.168.2.100:81','["200-299","300-399"]'),
(1,'Authentik (SSO)','http',1,60,60,2,30,'http://192.168.2.100:9000/-/health/ready/','["200-299"]'),
(1,'AdGuard Home','http',1,60,60,2,30,'http://192.168.2.100:3000','["200-299","300-399"]'),
(1,'Defguard (VPN web)','http',1,60,60,2,30,'http://192.168.2.100:8000','["200-299","300-399"]'),
(1,'Nextcloud','http',1,60,60,2,30,'http://192.168.2.103:8081/status.php','["200-299"]'),
(1,'OnlyOffice','http',1,60,60,2,30,'http://192.168.2.103:8082/healthcheck','["200-299"]'),
(1,'Paperless-ngx','http',1,60,60,2,30,'http://192.168.2.103:8000','["200-299","300-399"]'),
(1,'Vaultwarden','http',1,60,60,2,30,'http://192.168.2.103:8080/alive','["200-299"]');
INSERT INTO monitor (user_id,name,type,active,interval,retry_interval,maxretries,timeout,hostname,port) VALUES
(1,'Proxmox1 (8006)','port',1,60,60,2,30,'192.168.2.111',8006),
(1,'Proxmox2 (8006)','port',1,60,60,2,30,'192.168.2.112',8006),
(1,'Proxmox3 (8006)','port',1,60,60,2,30,'192.168.2.113',8006),
(1,'AdGuard DNS','port',1,60,60,2,30,'192.168.2.100',53),
(1,'Wazuh Dashboard','port',1,60,60,2,30,'192.168.2.102',443),
(1,'Wazuh Indexer','port',1,60,60,2,30,'192.168.2.102',9200);
INSERT INTO monitor (user_id,name,type,active,interval,retry_interval,maxretries,timeout,hostname) VALUES
(1,'VM101 Seguridad','ping',1,60,60,2,30,'192.168.2.100'),
(1,'VM102 Monitorizacion','ping',1,60,60,2,30,'192.168.2.102'),
(1,'VM103 Productividad','ping',1,60,60,2,30,'192.168.2.103'),
(1,'VM104 Aplicaciones','ping',1,60,60,2,30,'192.168.2.104');
EOSQL
)
echo "$SQL" | sudo tee "$DATA/import.sql" >/dev/null
cd /opt/stacks/uptimekuma && sudo docker compose stop
sudo docker run --rm -v "$DATA":/data alpine sh -c "apk add -q sqlite && sqlite3 /data/kuma.db < /data/import.sql && sqlite3 /data/kuma.db 'select count(*) from monitor'"
cd /opt/stacks/uptimekuma && sudo docker compose start
