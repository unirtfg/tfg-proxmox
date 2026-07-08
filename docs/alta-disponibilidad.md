# Alta Disponibilidad (HA)

Como el almacenamiento es **local-ZFS** (no compartido), la HA se basa en **replicación
ZFS** entre nodos: cada VM tiene una copia reciente en su nodo compañero, y si el nodo
cae, Proxmox la reinicia allí.

## Diseño

| VM        | Nodo home | Compañero (réplica) | Regla de afinidad |
|-----------|-----------|---------------------|-------------------|
| 101       | proxmox1  | proxmox2            | `aff-p1p2` (proxmox1:2, proxmox2:1, strict) |
| 102, 103  | proxmox2  | proxmox3            | `aff-p2p3` (proxmox2:2, proxmox3:1, strict) |
| 104       | proxmox3  | proxmox1            | `aff-p3p1` (proxmox3:2, proxmox1:1, strict) |

- **Replicación:** cada 15 min (`schedule */15`) por la red **`vmbr_ha` (10.10.100.0/24)**,
  fijada en *Datacenter → Options → Migration* (`type=secure,network=10.10.100.0/24`).
- **Recursos HA:** las 4 VMs con `state=started`.
- **Reglas (PVE 9):** en Proxmox 9 los antiguos *HA groups* se sustituyen por *HA rules*
  de tipo `node-affinity` (prioridad de nodo + `strict` = restringido a esos nodos).
- **Tolerancia:** caída de **1 nodo**. RPO ≈ 15 min (lo que se pierde es lo cambiado desde
  la última réplica). Bajar a `*/5` si se requiere menos pérdida.

Todo se aplica con [`scripts/40-proxmox-ha.sh`](../scripts/40-proxmox-ha.sh).

## Requisitos
- `local-zfs` con el mismo nombre en los 3 nodos.
- API token con `Sys.Modify` (para fijar la red de migración).
- `vm.max_map_count` no aplica aquí (es de Wazuh).

## Prueba de failover
```bash
# Apagar bruscamente un nodo (p. ej. proxmox1) y observar:
pvesh get /cluster/ha/status/current     # la VM 101 pasa a proxmox2
# Al volver el nodo, regresan a su home (prioridad) y la replicación se reanuda.
```
Verificar que la réplica viaja por la red dedicada:
```bash
pvesh get /nodes/proxmox1/replication/101-0/log   # "using secure transmission over 10.10.100.x"
```
