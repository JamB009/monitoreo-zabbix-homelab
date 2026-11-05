#!/usr/bin/env bash
#
# backup-zabbix.sh - Respaldo de configuración de Zabbix (Ubuntu + PostgreSQL)
#
# Guarda:
#   - Volcado de la base "zabbix" SIN datos históricos (hosts, items, triggers,
#     acciones, usuarios y medios sí se respaldan)
#   - Copia de /etc/zabbix y de la configuración de Nginx
# Rotación: conserva los últimos N respaldos.
#
# Uso:  sudo ./backup-zabbix.sh
# Cron: 30 2 * * * root /usr/local/sbin/backup-zabbix.sh >> /var/log/backup-zabbix.log 2>&1
#
# ATENCIÓN: los respaldos contienen secretos (token de Telegram, SMTP, PSK).
# Quedan con permisos 600 y NO deben subirse a GitHub.

set -euo pipefail

DEST="${DEST:-/var/backups/zabbix}"
DB_NAME="${DB_NAME:-zabbix}"
KEEP="${KEEP:-7}"
STAMP="$(date +%Y%m%d-%H%M)"

if [[ $EUID -ne 0 ]]; then
  echo "Ejecuta como root (sudo)." >&2
  exit 1
fi

mkdir -p "$DEST"
chmod 700 "$DEST"
umask 077

echo "[$(date '+%F %T')] Iniciando respaldo ($STAMP)"

# 1) Base de datos: formato custom, sin datos de tablas históricas
DB_FILE="$DEST/zabbix-db-$STAMP.dump"
sudo -u postgres pg_dump -Fc \
  --exclude-table-data='history*' \
  --exclude-table-data='trends*' \
  "$DB_NAME" > "$DB_FILE"
echo "  BD:      $DB_FILE ($(du -h "$DB_FILE" | cut -f1))"

# 2) Configuración
CONF_FILE="$DEST/zabbix-conf-$STAMP.tar.gz"
tar -czf "$CONF_FILE" /etc/zabbix /etc/nginx/sites-available /etc/nginx/conf.d 2>/dev/null || \
  tar -czf "$CONF_FILE" /etc/zabbix
echo "  Config:  $CONF_FILE ($(du -h "$CONF_FILE" | cut -f1))"

# 3) Rotación
for patron in 'zabbix-db-*.dump' 'zabbix-conf-*.tar.gz'; do
  ls -1t "$DEST"/$patron 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f --
done

echo "[$(date '+%F %T')] Respaldo terminado. Archivos actuales:"
ls -lh "$DEST"
