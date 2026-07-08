# Instalación de cero a producción

Runbook para reproducir toda la infraestructura partiendo de un clúster Proxmox limpio.

## Fase 0 — Prerrequisitos (en el clúster y en tu equipo)

**En el clúster Proxmox (una vez, a nivel de host/install):**
1. Instalar Proxmox VE 9 en los 3 nodos y **formar el clúster** (`pvecm create` / `pvecm add`).
2. Crear los **bridges** en cada nodo: `vmbr0` (192.168.2.0/24, con gateway), `vmbr_cl`
   (10.10.10.0/24) y `vmbr_ha` (10.10.100.0/24). *(Esto es config de nodo; no lo hace el token.)*
3. Tener **`local-zfs`** (pool ZFS con el mismo nombre) en los 3 nodos.
4. Crear un **API Token**: `Datacenter → Permissions → API Tokens`, usuario `root@pam`,
   y darle rol **Administrator sobre `/`** (incluye `Sys.Modify`, necesario para HA y red de migración).
5. (Opcional) Un equipo con **Proxmox Backup Server** para las copias.

**En tu equipo de control:**
```bash
# Herramientas
terraform -v   # >= 1.5
ansible --version
git, curl, jq, ssh-keygen

# Repo + clave SSH para las VMs
git clone https://github.com/unirtfg/tfg-proxmox.git && cd tfg-proxmox
ssh-keygen -t ed25519 -f ~/.ssh/proxmox_vms -N ''
ansible-galaxy collection install community.docker community.general ansible.posix
```
Además: cuenta **DuckDNS** (subdominio + token).

---

## Fase 1 — VMs Debian (Terraform)
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
#  edita: pve_endpoint, pve_api_token, ci_password, ssh_public_key (~/.ssh/proxmox_vms.pub)
terraform init
terraform apply        # crea la imagen Debian 13 + VMs 101, 102, 103, 104
```

---

## Fase 2 — Configuración de las VMs (Ansible)
```bash
cd ../ansible
cp inventory.ini.example inventory.ini                 # IPs de tus VMs
cp group_vars/all.yml.example group_vars/all.yml       # secretos, duckdns, dominio, email
ansible-playbook site.yml
# -> Docker + zona horaria en todas; stacks de seguridad, productividad y monitorización
```

---

## Fase 3 — Configuración vía API / occ (scripts)
```bash
cd ../scripts
export BASE_DOMAIN=tusub.duckdns.org DUCKDNS_TOKEN=xxxx

# 3.1 Nginx Proxy Manager: admin + cert wildcard + proxy hosts
NPM_EMAIL=admin@tu.com NPM_PASS=*** ./30-npm-setup.sh

# 3.2 Authentik: completar setup inicial en https://auth.$BASE_DOMAIN/if/flow/initial-setup/
#     crear un token API (Directory -> Tokens) y luego:
AK_TOKEN=*** ./31-authentik-setup.sh
#     en Nextcloud (VM103) registrar el proveedor user_oidc con la orden que imprime el script.

# 3.3 OnlyOffice en Nextcloud (ejecutar en VM103)
OO_JWT=*** ./33-nextcloud-onlyoffice.sh

# 3.4 Defguard VPN: en https://vpn.$BASE_DOMAIN crear la Location (10.8.0.1/24,
#     endpoint $BASE_DOMAIN, puerto 51821, AllowedIPs 192.168.2.0/24,10.8.0.0/24,
#     DNS 192.168.2.100) -> copiar el TOKEN -> en VM101:
DEFGUARD_TOKEN=*** ./32-defguard-gateway.sh

# 3.5 Alta Disponibilidad (replicación ZFS + reglas HA)
export PVE_HOST=192.168.2.111:8006 PVE_TOKEN='root@pam!token=...'
./40-proxmox-ha.sh

# 3.6 Wazuh: cambiar contraseña (en VM102)
./41-wazuh-change-password.sh 'NUEVA_PASS'

# 3.7 Uptime Kuma: monitores (en VM102) o importar stacks/uptimekuma/monitors.json
./42-uptimekuma-monitors.sh

# 3.8 Agente Wazuh en un cliente Windows (PowerShell admin)
#     .\50-wazuh-agent.ps1 -Manager 192.168.2.102
```

---

## Fase 4 — Pasos interactivos finales
- **AdGuard:** asistente inicial en `http://192.168.2.100:3000` y reescritura split-DNS
  `*.$BASE_DOMAIN → 192.168.2.100`.
- **Uptime Kuma:** crear el usuario admin en el primer acceso.
- **Router:** reenviar **`51821/udp` → 192.168.2.100** (acceso VPN desde fuera).
- **DNS de la red/cliente:** apuntar a **192.168.2.100** (AdGuard) para resolver los dominios.

---

## Qué queda automatizado vs manual
| Automatizado (IaC) | Manual / interactivo |
|--------------------|----------------------|
| VMs Debian, Docker, todos los stacks | Onboarding de Uptime Kuma |
| Cert wildcard, proxy hosts, OIDC, grupos | Crear la *Location* de Defguard (token) |
| Replicación ZFS + HA | Asistente inicial de AdGuard / Authentik |
| Cambio de contraseña de Wazuh, monitores | Reenvío de puerto en el router |
