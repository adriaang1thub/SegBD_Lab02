#!/usr/bin/env bash
# F7. Verificación automatizada del stack endurecido (PASS/FAIL). Código de salida 0 solo si todo pasa.
set -uo pipefail
cd "$(dirname "$0")/.."
C="docker compose -f docker-compose.secure.yml"
P=0; F=0
ok()  { echo "[PASS] $1 -> $2"; P=$((P+1)); }
ko()  { echo "[FAIL] $1 -> $2"; F=$((F+1)); }

echo "== Superficie de red (desde el host)"
for port in 5432 3306; do
  if timeout 2 bash -c "exec 3<>/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
    ko "Puerto $port cerrado en el host" "ABIERTO"
  else
    ok "Puerto $port cerrado en el host" "sin respuesta"
  fi
done

echo "== Comprobaciones desde la red interna (app/checks.py)"
OUT=$($C exec -T app python checks.py)
echo "$OUT"
P=$((P + $(grep -c '^\[PASS\]' <<<"$OUT"))); F=$((F + $(grep -c '^\[FAIL\]' <<<"$OUT")))

echo "== Auditoría y logs"
n=$($C logs postgres 2>/dev/null | grep -c "AUDIT: SESSION")
[ "$n" -gt 0 ] && ok "pgaudit registra sentencias" "$n eventos AUDIT" || ko "pgaudit registra sentencias" "0 eventos"
n=$($C logs postgres 2>/dev/null | grep -c "connection authorized: user=appuser")
[ "$n" -gt 0 ] && ok "log_connections registra a appuser" "$n conexiones" || ko "log_connections registra a appuser" "0"
n=$($C exec -T mysql sh -c "grep -c 'Connect.*app@' /var/log/mysql/general.log")
[ "${n:-0}" -gt 0 ] && ok "MySQL general_log registra conexiones de app" "$n conexiones" \
                    || ko "MySQL general_log registra conexiones de app" "0"
v=$($C exec -T mysql mysql -N -e "SELECT CONCAT(@@slow_query_log, '/', @@long_query_time)")
[ "${v%%/*}" = "1" ] && ok "MySQL slow_query_log activo" "ON, long_query_time=${v##*/}" \
                     || ko "MySQL slow_query_log activo" "$v"

echo "== Copias de seguridad"
if [ -f backups/LATEST ] && (cd backups && sha256sum -c --quiet "SHA256SUMS_$(cat LATEST)") >/dev/null 2>&1; then
  ok "Última copia íntegra (SHA-256)" "$(cat backups/LATEST)"
else
  ko "Última copia íntegra (SHA-256)" "no hay copia o la huella no coincide"
fi

echo
echo "RESULTADO: $P PASS / $F FAIL"
[ "$F" -eq 0 ]
