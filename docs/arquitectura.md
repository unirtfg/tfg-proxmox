# Arquitectura

## Clúster
- **3 nodos** Proxmox VE 9 (`proxmox1/2/3`, `192.168.2.111/112/113`), quórum impar.
- Hardware de referencia por nodo: AMD Ryzen, 32 GB RAM, HDD (sistema) + NVMe (VMs).

## Redes (segmentadas con VLAN en switch gestionable)
| Bridge    | Subred           | Uso |
|-----------|------------------|-----|
| `vmbr0`   | 192.168.2.0/24   | VMs + gestión Proxmox (con gateway a Internet) |
| `vmbr_cl` | 10.10.10.0/24    | corosync / comunicación del clúster |
| `vmbr_ha` | 10.10.100.0/24   | replicación ZFS + migración HA (alta velocidad) |

## Almacenamiento
- `local-zfs` (ZFS) en cada nodo → permite **replicación** entre nodos y, con ella, HA
  sin necesidad de cabina compartida.
- Copias de seguridad: equipo aparte con **Proxmox Backup Server** (regla 3-2-1).

## Capas de servicio
1. **Infraestructura base:** virtualización + HA (Terraform + Ansible + scripts).
2. **Acceso/seguridad:** Nginx Proxy Manager (TLS wildcard), Authentik (SSO/OIDC),
   AdGuard (DNS + filtrado + split-DNS), CrowdSec (detección + bloqueo en firewall),
   Defguard (VPN WireGuard).
3. **Servicios corporativos:** Nextcloud + OnlyOffice + Paperless-ngx (gestión documental
   con OCR vía carpeta puente), Vaultwarden (contraseñas).
4. **Observabilidad:** Wazuh (SIEM, + agentes), Uptime Kuma (disponibilidad).

## Flujo de acceso
- **Externo:** cliente → VPN Defguard (WireGuard, `tudominio.duckdns.org:51821/udp`) →
  red interna. DNS de la VPN = AdGuard (`192.168.2.100`), que resuelve
  `*.tudominio.duckdns.org → 192.168.2.100` (split-DNS) → NPM → servicio (TLS válido).
- **Interno (LAN):** DNS a AdGuard (split-DNS) y acceso por los mismos dominios.
- No se exponen los servicios web a Internet; el punto de entrada remoto es la VPN.

## SSO
- **OIDC nativo** en Nextcloud (`user_oidc`) y Paperless (`allauth`), con auto-aprovisionamiento.
- Grupo `empresa` en Authentik vinculado a las aplicaciones controla quién accede.
