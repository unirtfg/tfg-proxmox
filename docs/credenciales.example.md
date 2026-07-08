# Credenciales (PLANTILLA)

> Copia este fichero a `docs/credenciales.md` (está en `.gitignore`) y rellénalo, o mejor
> guárdalo en **Vaultwarden**. NO subas credenciales reales al repositorio.

## Acceso base
- Proxmox API token: `root@pam!terraform=________`
- SSH a VMs: usuario `sysadmin`, clave `~/.ssh/proxmox_vms`
- cloud-init password: `________`
- DuckDNS: subdominio `________` · token `________`

## Servicios (admin)
| Servicio | URL | Usuario | Contraseña |
|----------|-----|---------|-----------|
| Authentik | https://auth.<dominio> | akadmin | ____ |
| Nginx Proxy Manager | https://npm.<dominio> | ____@____ | ____ |
| AdGuard Home | https://adguard.<dominio> | admin | ____ |
| Defguard | https://vpn.<dominio> | admin | ____ |
| Wazuh | https://wazuh.<dominio> | admin | ____ |
| Uptime Kuma | https://status.<dominio> | ____ | ____ |
| Nextcloud (local) | https://nextcloud.<dominio> | admin | ____ |
| Paperless (local) | https://paperless.<dominio> | admin | ____ |
| Vaultwarden (admin panel) | https://vault.<dominio>/admin | — | token: ____ |

## SSO (Authentik)
- Token API: `________`
- Usuarios: `empleado` / ____ , `luis` / ____ (grupo `empresa`)
- OIDC Nextcloud: client_id `____` / secret `____`
- OIDC Paperless: client_id `____` / secret `____`

## Secretos internos
Están en los `.env` de cada stack en `/opt/stacks/<stack>/.env` de cada VM
(BD, JWT de OnlyOffice, secretos de Authentik/Defguard, etc.).
