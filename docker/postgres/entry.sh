#!/bin/bash
# Copia los certificados con el propietario y los permisos que exige PostgreSQL (clave 0600)
# y deja credenciales de administración en /root/.pgpass (solo dentro del contenedor).
set -euo pipefail
D=/var/lib/postgresql/certs
install -d -o postgres -g postgres -m 700 "$D"
install -o postgres -g postgres -m 600 /certs-src/pg.key "$D/server.key"
install -o postgres -g postgres -m 644 /certs-src/pg.crt "$D/server.crt"
install -o postgres -g postgres -m 644 /certs-src/ca.crt "$D/ca.crt"
umask 077
printf '*:*:*:postgres:%s\n*:*:tienda:backup_user:%s\n' "$POSTGRES_PASSWORD" "$PG_BACKUP_PASSWORD" > /root/.pgpass
exec docker-entrypoint.sh "$@"
