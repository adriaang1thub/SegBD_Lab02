#!/usr/bin/env bash
# F5. Busca emails en claro dentro del fichero de datos de la tabla usuarios (lo que vería quien robe el disco)
set -euo pipefail
cd "$(dirname "$0")/.."
C="docker compose -f docker-compose.secure.yml"
$C exec -T postgres psql -U postgres -d tienda -qc "CHECKPOINT"
F=$($C exec -T postgres psql -U postgres -d tienda -Atc "SELECT pg_relation_filepath('usuarios')")
echo "[disco] fichero de la tabla usuarios: \$PGDATA/$F"
N=$($C exec -T postgres sh -c "grep -a -o '[a-z]*@[a-z]*\.lab' /var/lib/postgresql/data/$F | sort -u" || true)
if [ -n "$N" ]; then
  echo "[disco] emails legibles en claro en el fichero:"; echo "$N" | sed 's/^/    /'
else
  echo "[disco] 0 emails legibles en claro en el fichero"
fi
