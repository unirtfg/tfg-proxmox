# Scripts de configuración (vía API / occ)

Pasos que no encajan en Terraform/Ansible porque se hacen contra las APIs de cada
servicio una vez desplegado. Ejecutar **en este orden** tras `terraform apply` y
`ansible-playbook site.yml`.

| # | Script | Qué hace | Variables |
|---|--------|----------|-----------|
| 30 | `30-npm-setup.sh` | Admin de NPM + cert wildcard (DNS-01 DuckDNS) + proxy hosts | `NPM_URL NPM_EMAIL NPM_PASS BASE_DOMAIN DUCKDNS_TOKEN` |
| 31 | `31-authentik-setup.sh` | akadmin + token API + proveedores OIDC (Nextcloud/Paperless) + grupo `empresa` | `AK_URL AK_TOKEN BASE_DOMAIN` |
| 32 | `32-defguard-gateway.sh` | Levanta el gateway WireGuard de Defguard (puerto 51821) | `DEFGUARD_TOKEN` (de la Location) |
| 33 | `33-nextcloud-onlyoffice.sh` | Instala/integra la app ONLYOFFICE en Nextcloud (occ) | `OO_JWT BASE_DOMAIN` |
| 40 | `40-proxmox-ha.sh` | Red de migración + replicación ZFS + recursos y reglas HA | `PVE_HOST PVE_TOKEN` |
| 41 | `41-wazuh-change-password.sh` | Cambia la contraseña admin del indexer de Wazuh | (se ejecuta en VM102) |
| 42 | `42-uptimekuma-monitors.sh` | Inserta los monitores en Uptime Kuma | (se ejecuta en VM102) |
| 43 | `43-pbs-backup.sh` | Backups a PBS (00:00/12:00) + aviso de resultado por Telegram | `PVE_HOST PVE_TOKEN TG_TOKEN TG_CHATID` |
| 50 | `50-wazuh-agent.ps1` | Instala el agente Wazuh en un cliente Windows | `WAZUH_MANAGER` |

## Notas importantes

- **Defguard (32):** el `DEFGUARD_TOKEN` se obtiene en la web de Defguard al crear la
  *Location* (subred `10.8.0.1/24`, endpoint `tudominio.duckdns.org`, puerto `51821`,
  Allowed IPs `192.168.2.0/24,10.8.0.0/24`, DNS `192.168.2.100`). El gateway corre con
  `network_mode: host` + `NET_ADMIN`; en el host hace falta `ip_forward=1` y permitir
  `wg0` en la cadena `DOCKER-USER` (FORWARD), persistido con un servicio systemd.

- **Authentik (31):** crea por API un *OAuth2/OpenID Provider* + *Application* por servicio
  (redirect URIs: Nextcloud `…/apps/user_oidc/code`, Paperless
  `…/accounts/oidc/authentik/login/callback/`), el grupo `empresa` y los *policy bindings*
  para restringir acceso. Genera también el JSON `PL_OIDC_PROVIDERS` para Paperless.

- **Wazuh (41):** la contraseña se cambia regenerando el hash con `hash.sh`, editando
  `internal_users.yml` **dentro del contenedor preservando el inodo** (el bind-mount de
  fichero único se rompe con `sed -i`), aplicando `securityadmin.sh` y propagando la nueva
  clave a `INDEXER_PASSWORD` del manager y dashboard.

- **Uptime Kuma (42):** sin API REST simple; o se importa `stacks/uptimekuma/monitors.json`
  desde *Settings → Backup → Import*, o se insertan en su SQLite (`/app/data/kuma.db`,
  tabla `monitor`, `user_id=1`) con el contenedor parado.
