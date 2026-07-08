# Mantenimiento y actualizaciones

Estrategia por capas. Principio: **copia primero, actualiza en caliente (HA), verifica con la monitorización.**

## Qué está automatizado vs manual

| Elemento | Modo | Mecanismo |
|----------|------|-----------|
| Parches de seguridad del **SO** (VMs Debian) | **Automático** | `unattended-upgrades` |
| Contenedores **sin estado / seguros** | **Automático** (04:00 diario) | **Watchtower** (lista acotada por VM) |
| Contenedores **stateful / críticos** | **Manual** | `docker compose pull && up -d` consciente + backup |
| **Nodos Proxmox** (hipervisor) | Manual (rolling) | `node-maintenance` + `apt full-upgrade` + reboot |
| **Certificados** Let's Encrypt | **Automático** | NPM (renovación) |
| Listas/escenarios **CrowdSec/AdGuard** | **Automático** | feeds propios |

### Auto-actualizados por Watchtower (seguros)
- VM101: `adguard`, `duckdns`, `crowdsec`
- VM102: `uptime-kuma`
- VM103: `vaultwarden`

### NO auto-actualizados (manual, requieren backup + versión consciente)
`npm`, `authentik` (+db/redis), `nextcloud` (+db/redis), `paperless` (+db/redis),
`onlyoffice`, `wazuh`, `defguard` (+db). Motivo: migraciones de BD y *breaking changes*
entre versiones mayores; una actualización ciega puede corromper datos.

## Procedimientos

### Nodos Proxmox (rolling, sin cortar servicio)
```bash
ha-manager crm-command node-maintenance enable  proxmoxN   # HA migra sus VMs
apt update && apt full-upgrade -y && reboot
ha-manager crm-command node-maintenance disable proxmoxN   # reincorpora
```

### Servicios stateful (actualización consciente)
```bash
qm snapshot <vmid> pre-update            # red de seguridad (rollback con qm rollback)
cd /opt/stacks/<stack>
docker compose pull && docker compose up -d
# verificar en Uptime Kuma + logs en Wazuh; si falla -> qm rollback
```
Nextcloud: subir **una versión mayor cada vez**. Wazuh: seguir su guía de upgrade.

### Aplicar cambios desde el repo (IaC)
Subir versión de imagen = editar el tag en `stacks/<stack>/compose.yaml`, commit, y:
```bash
ansible-playbook ansible/site.yml --limit <grupo>
```
Recomendado **fijar tags** (`:16.4` en vez de `:latest`) en los stacks críticos.

## Copias de seguridad
- **Proxmox Backup Server**: programadas, regla 3-2-1, deduplicación.
- Snapshot puntual antes de cualquier actualización arriesgada.
- Los datos de los contenedores viven en `/opt/stacks/*/` (incluidos en el backup de la VM).

## Avisos de nuevas versiones (Diun + Telegram) — ACTIVO
**Diun** (Docker Image Update Notifier) está desplegado en VM101/102/103
(`stacks/diun/compose.yaml`), comprobando **a diario a las 06:00** y notificando por
**Telegram** cuando hay imagen nueva (el `hostname` indica la VM). Vigila todos los
contenedores: los seguros los aplica Watchtower solo; de los manuales te avisa para que
decidas cuándo actualizarlos (con backup).

Configuración (en `.env`/secretos, nunca en git):
`DIUN_TG_TOKEN` (bot de @BotFather), `DIUN_TG_CHATID` (de @userinfobot), `DIUN_HOSTNAME`.
