# Infraestructura local de alta disponibilidad y bajo coste para PYMES con Proxmox

Infraestructura como código (IaC) del despliegue de un clúster **Proxmox VE 9** de 3 nodos
con **alta disponibilidad**, sobre el que se ejecutan servicios corporativos en contenedores
Docker, VPN, SSO, copias de seguridad y monitorización — todo con software libre y hardware
de bajo coste.

> TFG — Grado en Ingeniería Informática. Este repo reproduce de forma automatizada la
> infraestructura descrita en la memoria.

---

## 1. Arquitectura

```
                         Internet
                            │
                      ┌─────┴─────┐
                      │  Router   │  (DuckDNS: tudominio.duckdns.org)
                      │  + NAT    │  51821/udp → VPN
                      └─────┬─────┘
                            │ vmbr0 192.168.2.0/24
   ┌─────────────┬──────────┴──────────┬─────────────┐
   │ proxmox1    │ proxmox2            │ proxmox3    │   Clúster "cl-empresa"
   │ .111        │ .112                │ .113        │   (quórum 3 nodos)
   └─────────────┴─────────────────────┴─────────────┘
   Redes por nodo:
     vmbr0     192.168.2.0/24    VMs + gestión (gateway)
     vmbr_cl   10.10.10.0/24     corosync / clúster
     vmbr_ha   10.10.100.0/24    replicación ZFS + migración HA
```

### Máquinas virtuales

| VMID | Nombre             | Nodo home | IP            | vCPU | RAM  | Disco | Rol |
|------|--------------------|-----------|---------------|------|------|-------|-----|
| 101  | vm-seguridad       | proxmox1  | 192.168.2.100 | 2    | 4 GB | 32 GB | NPM, DuckDNS, AdGuard, CrowdSec, Authentik, Defguard |
| 102  | vm-monitorizacion  | proxmox2  | 192.168.2.102 | 4    | 8 GB | 48 GB | Wazuh (SIEM), Uptime Kuma |
| 103  | vm-productividad   | proxmox2  | 192.168.2.103 | 4    | 6 GB | 64 GB | Nextcloud, OnlyOffice, Paperless-ngx, Vaultwarden |
| 104  | vm-aplicaciones    | proxmox3  | 192.168.2.104 | 4    | 8 GB | 32 GB | (servidor de aplicaciones / ThinLinc) |

Todas las VMs parten de una **plantilla Debian 13 cloud-init** (VMID 9000) y usan
almacenamiento **local-zfs**.

### Servicios y dominios

Publicados tras **Nginx Proxy Manager** con certificado wildcard `*.tudominio.duckdns.org`
(Let's Encrypt vía DNS-01 de DuckDNS):

| Subdominio | Servicio | VM:puerto interno |
|------------|----------|-------------------|
| `npm.`        | Nginx Proxy Manager | 192.168.2.100:81 |
| `auth.`       | Authentik (SSO/OIDC) | 192.168.2.100:9000 |
| `adguard.`    | AdGuard Home | 192.168.2.100:3000 |
| `vpn.`        | Defguard (web/enrollment) | 192.168.2.100:8000 |
| `wazuh.`      | Wazuh Dashboard | 192.168.2.102:443 |
| `status.`     | Uptime Kuma | 192.168.2.102:3001 |
| `nextcloud.`  | Nextcloud | 192.168.2.103:8081 |
| `office.`     | OnlyOffice Document Server | 192.168.2.103:8082 |
| `paperless.`  | Paperless-ngx | 192.168.2.103:8000 |
| `vault.`      | Vaultwarden | 192.168.2.103:8080 |

---

## 2. Estructura del repositorio

```
tfg-proxmox/
├── terraform/      Aprovisiona la plantilla y las 4 VMs en Proxmox (provider bpg/proxmox)
├── ansible/        Configura las VMs: Docker, stacks, sysctl, agentes...
├── stacks/         docker-compose de cada grupo de servicios (+ .env.example)
├── scripts/        Configuración hecha vía API (NPM, Authentik, HA/replicación, agente Wazuh)
└── docs/           Documentación detallada (arquitectura, HA, SSO, credenciales)
```

---

## 3. Requisitos previos

- Clúster **Proxmox VE 9** de 3 nodos ya formado, con red `vmbr0`, `vmbr_cl`, `vmbr_ha`
  y almacenamiento `local-zfs` en cada nodo.
- Un **API Token** de Proxmox con rol `Administrator` sobre `/` (incluye `Sys.Modify`,
  necesario para HA, red de migración y cambios de nodo).
- Cuenta **DuckDNS** (subdominio + token).
- En el equipo de control: `terraform` ≥ 1.5, `ansible` ≥ 2.15, `curl`, `jq`.

---

## 4. Orden de despliegue

```bash
# 1) VMs e infraestructura base
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edita con tus datos
terraform init && terraform apply

# 2) Configuración de las VMs (Docker + stacks)
cd ../ansible
cp inventory.ini.example inventory.ini         # IPs de tus VMs
cp group_vars/all.yml.example group_vars/all.yml  # secretos/dominios
ansible-playbook -i inventory.ini site.yml

# 3) Configuración vía API (proxy inverso, SSO, alta disponibilidad)
cd ../scripts
export PVE_HOST=192.168.2.111:8006 PVE_TOKEN='root@pam!token=...'
./30-npm-setup.sh        # NPM: admin, cert wildcard, proxy hosts
./31-authentik-setup.sh  # Authentik: OIDC para Nextcloud/Paperless, grupos
./40-proxmox-ha.sh       # Replicación ZFS + reglas HA
./50-wazuh-agent.ps1     # (opcional) agente Wazuh en un cliente Windows
```

Ver [`docs/instalacion.md`](docs/instalacion.md) para el paso a paso detallado.

---

## 5. Seguridad / secretos

Ningún secreto real se versiona. Usa los ficheros `*.example` como plantilla:
copia, renómbralos (sin `.example`) y rellena tus valores. Esos ficheros reales
están en `.gitignore`. Ver [`docs/credenciales.example.md`](docs/credenciales.example.md).

## 6. Alta disponibilidad

Replicación ZFS por la red `vmbr_ha` cada 15 min + reglas de afinidad de nodo
(Proxmox 9 usa *HA rules* en lugar de los antiguos *groups*). Tolera la caída de
un nodo. Detalles en [`docs/alta-disponibilidad.md`](docs/alta-disponibilidad.md).

## 7. Mantenimiento y actualizaciones

Parches de seguridad del SO automáticos (`unattended-upgrades`) y auto-actualización
de los contenedores sin estado/seguros con **Watchtower** (los stateful se actualizan a
mano, con backup). Detalles en [`docs/mantenimiento.md`](docs/mantenimiento.md).

## Licencia

Software desplegado: en su mayoría open source. Este repositorio: MIT.
