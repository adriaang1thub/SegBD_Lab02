#!/usr/bin/env bash
# F6. Restaura la última copia en una base "tienda_restore" y compara con la original:
# huella SHA-256 del fichero, número de filas y hash del contenido de cada tabla.
set -uo pipefail
cd "$(dirname "$0")/.."
C="docker compose -f docker-compose.secure.yml"
TS=${1:-$(cat backups/LATEST)}
FALLOS=0

echo "[1] Integridad de los ficheros de copia"
(cd backups && sha256sum -c "SHA256SUMS_$TS") || FALLOS=$((FALLOS+1))

echo "[2] Restauración PostgreSQL -> tienda_restore (pg_restore)"
$C exec -T postgres psql -U postgres -q -c "DROP DATABASE IF EXISTS tienda_restore" \
  -c "CREATE DATABASE tienda_restore" 2>&1 | grep -v NOTICE
$C exec -T postgres pg_restore -U postgres -d tienda_restore --exit-on-error "/backups/pg_tienda_$TS.dump" \
  && echo "    OK" || FALLOS=$((FALLOS+1))

echo "[3] Restauración MySQL -> tienda_restore (mysql < dump)"
$C exec -T mysql sh -c "mysql -e 'DROP DATABASE IF EXISTS tienda_restore; CREATE DATABASE tienda_restore' \
  && mysql tienda_restore < /backups/my_tienda_$TS.sql" && echo "    OK" || FALLOS=$((FALLOS+1))

echo "[4] Consistencia original vs restaurada"
printf "    %-6s %-12s %-44s %s\n" "SGBD" "TABLA" "ORIGINAL" "RESULTADO"
for t in usuarios productos comentarios; do
  q="SELECT count(*) || ' filas md5=' || left(md5(coalesce(string_agg(x::text, '|' ORDER BY x.id), '')), 16) FROM $t x"
  a=$($C exec -T postgres psql -U postgres -d tienda -Atc "$q")
  b=$($C exec -T postgres psql -U postgres -d tienda_restore -Atc "$q")
  [ "$a" = "$b" ] && r="IGUAL" || { r="DISTINTO ($b)"; FALLOS=$((FALLOS+1)); }
  printf "    %-6s %-12s %-44s %s\n" "PG" "$t" "$a" "$r"
done
for t in usuarios productos comentarios; do
  q="SELECT CONCAT(COUNT(*), ' filas') FROM DB.$t; CHECKSUM TABLE DB.$t;"
  a=$($C exec -T mysql mysql -N -e "${q//DB/tienda}" | awk 'NR==1{f=$0} NR==2{print f" checksum="$2}')
  b=$($C exec -T mysql mysql -N -e "${q//DB/tienda_restore}" | awk 'NR==1{f=$0} NR==2{print f" checksum="$2}')
  [ "$a" = "$b" ] && r="IGUAL" || { r="DISTINTO ($b)"; FALLOS=$((FALLOS+1)); }
  printf "    %-6s %-12s %-44s %s\n" "MySQL" "$t" "$a" "$r"
done

echo
[ "$FALLOS" -eq 0 ] && echo "RESULTADO: restauración verificada, copias íntegras y consistentes" \
                    || echo "RESULTADO: $FALLOS comprobaciones fallidas"
exit "$FALLOS"
