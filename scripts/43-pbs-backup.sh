#!/usr/bin/env bash
# Programa backups a Proxmox Backup Server (00:00 y 12:00) y notifica el resultado
# por Telegram (sistema de notificaciones nativo de PVE9: endpoint webhook + matcher).
#
# Requiere PVE_HOST, PVE_TOKEN (con Sys.Modify) y TG_TOKEN, TG_CHATID.
set -euo pipefail
: "${PVE_HOST:?}"; : "${PVE_TOKEN:?}"; : "${TG_TOKEN:?}"; : "${TG_CHATID:?}"
: "${PBS_STORAGE:=pbs}"; : "${BACKUP_VMIDS:=101,102,103,104}"
API="https://${PVE_HOST}/api2/json"; H=(-H "Authorization: PVEAPIToken=${PVE_TOKEN}")

echo "==> Job de backup (00:00 y 12:00, snapshot, retención)"
curl -sk "${H[@]}" -X POST \
  -d "schedule=00:00,12:00" -d "storage=${PBS_STORAGE}" -d "vmid=${BACKUP_VMIDS}" \
  -d "mode=snapshot" -d "enabled=1" -d "notes-template={{guestname}}" \
  --data-urlencode "prune-backups=keep-last=3,keep-daily=7,keep-weekly=4,keep-monthly=6" \
  -d "comment=Backup diario 00h y 12h a PBS" "$API/cluster/backup"

echo "==> Endpoint webhook a Telegram"
URL="https://api.telegram.org/bot${TG_TOKEN}/sendMessage?chat_id=${TG_CHATID}&text={{url-encode title}}%0A%0A{{url-encode message}}"
curl -sk "${H[@]}" -X POST -d "name=telegram" -d "method=post" \
  --data-urlencode "url=${URL}" -d "comment=Avisos a Telegram" \
  "$API/cluster/notifications/endpoints/webhook"

echo "==> Matcher: notificaciones de backup (type=vzdump) -> telegram"
curl -sk "${H[@]}" -X POST -d "name=backups-telegram" -d "target=telegram" \
  --data-urlencode "match-field=exact:type=vzdump" -d "mode=all" \
  -d "comment=Resultado de backups a Telegram" "$API/cluster/notifications/matchers"

echo "==> Test del target"
curl -sk "${H[@]}" -X POST "$API/cluster/notifications/targets/telegram/test"
echo; echo "Listo. Retención y prune también pueden gestionarse en el datastore del PBS."
