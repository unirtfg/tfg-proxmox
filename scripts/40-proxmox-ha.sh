#!/usr/bin/env bash
# Configura Alta Disponibilidad en Proxmox VE 9:
#   - Red de migración/replicación = vmbr_ha (10.10.100.0/24)
#   - Replicación ZFS de cada VM a su nodo compañero (cada 15 min)
#   - Recursos HA + reglas de afinidad de nodo (PVE9: "HA rules", no "groups")
#
# Requiere: PVE_HOST (ip:8006) y PVE_TOKEN ('user@realm!tokenid=secret') con rol Administrator.
set -euo pipefail
: "${PVE_HOST:?Define PVE_HOST=192.168.2.111:8006}"
: "${PVE_TOKEN:?Define PVE_TOKEN=root@pam!token=...}"
API="https://${PVE_HOST}/api2/json"
H=(-H "Authorization: PVEAPIToken=${PVE_TOKEN}")
q() { curl -sk -m 30 "${H[@]}" "$@"; }

echo "==> Red de migración/replicación: vmbr_ha (10.10.100.0/24)"
q -X PUT --data-urlencode "migration=type=secure,network=10.10.100.0/24" "$API/cluster/options"

echo "==> Jobs de replicación ZFS (VM -> nodo compañero)"
# id "vmid-N"  target=nodo compañero
# 101 seguridad(proxmox1), 102 monitorizacion(proxmox2), 103 productividad(proxmox2), 104 aplicaciones(proxmox3)
declare -A REPL=( [101-0]=proxmox2 [102-0]=proxmox3 [103-0]=proxmox3 [104-0]=proxmox1 )
for id in "${!REPL[@]}"; do
  q -X POST -d "id=${id}" -d "type=local" -d "target=${REPL[$id]}" \
       -d "schedule=*/15" -d "comment=HA replication" "$API/cluster/replication" || true
done

echo "==> Recursos HA (state=started)"
for sid in vm:101 vm:102 vm:103 vm:104; do
  q -X POST -d "sid=${sid}" -d "state=started" -d "max_restart=1" -d "max_relocate=1" \
       -d "comment=HA" "$API/cluster/ha/resources" || true
done

echo "==> Reglas de afinidad de nodo (home con prioridad mayor, restringido a home+compañero)"
q -X POST -d "type=node-affinity" -d "rule=aff-p1p2" -d "resources=vm:101" \
     -d "nodes=proxmox1:2,proxmox2:1" -d "strict=1" "$API/cluster/ha/rules" || true
q -X POST -d "type=node-affinity" -d "rule=aff-p2p3" -d "resources=vm:102,vm:103" \
     -d "nodes=proxmox2:2,proxmox3:1" -d "strict=1" "$API/cluster/ha/rules" || true
q -X POST -d "type=node-affinity" -d "rule=aff-p3p1" -d "resources=vm:104" \
     -d "nodes=proxmox3:2,proxmox1:1" -d "strict=1" "$API/cluster/ha/rules" || true

echo "==> Lanzar primera replicación"
declare -A SRC=( [101-0]=proxmox1 [102-0]=proxmox2 [103-0]=proxmox2 [104-0]=proxmox3 )
for id in "${!SRC[@]}"; do
  q -X POST "$API/nodes/${SRC[$id]}/replication/${id}/schedule_now" || true
done

echo "==> Estado HA:"
q "$API/cluster/ha/status/current"
echo; echo "Listo. Verifica que las réplicas sincronizan por 10.10.100.x con:"
echo "  pvesh get /nodes/<nodo>/replication/<id>/log"
