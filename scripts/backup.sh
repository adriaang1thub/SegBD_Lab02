#!/usr/bin/env bash
# F6. Copias de seguridad con usuarios dedicados de solo lectura + huella SHA-256 de cada fichero
set -euo pipefail
cd "$(dirname "$0")/.."
C="docker compose -f docker-compose.secure.yml"
TS=$(date +%Y%m%d_%H%M%S)

echo "[backup] PostgreSQL: pg_dump formato custom con backup_user (pg_read_all_data)"
$C exec -T postgres pg_dump -U backup_user -d tienda -F c -f "/backups/pg_tienda_$TS.dump"

echo "[backup] MySQL: mysqldump con el usuario backup (SELECT, SHOW VIEW, TRIGGER, LOCK TABLES)"
$C exec -T mysql sh -c "mysqldump --defaults-file=/root/backup.cnf --single-transaction \
  --no-tablespaces --set-gtid-purged=OFF --skip-dump-date tienda > /backups/my_tienda_$TS.sql"

cd backups
sha256sum "pg_tienda_$TS.dump" "my_tienda_$TS.sql" > "SHA256SUMS_$TS"
echo "$TS" > LATEST
echo "[backup] ficheros generados:"
ls -l "pg_tienda_$TS.dump" "my_tienda_$TS.sql"
echo "[backup] huellas SHA-256:"
cat "SHA256SUMS_$TS"
