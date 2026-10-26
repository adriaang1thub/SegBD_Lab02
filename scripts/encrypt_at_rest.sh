#!/usr/bin/env bash
# F5. Cifra la columna email con pgcrypto. La clave (PGCRYPTO_KEY) se lee de .env y se envía
# a psql por stdin (\set), así no aparece en la línea de comandos ni en el historial.
set -euo pipefail
cd "$(dirname "$0")/.."
. ./.env
{ printf '\\set k %s\n' "'$PGCRYPTO_KEY'"; cat sql/encrypt_email.sql; } |
  docker compose -f docker-compose.secure.yml exec -T postgres psql -U postgres -d tienda -v ON_ERROR_STOP=1
