#!/usr/bin/env bash
# Genera .env con contraseñas aleatorias (permisos 600). El fichero está en .gitignore.
set -eu
cd "$(dirname "$0")/.."
umask 077
r() { openssl rand -hex "${1:-16}"; }
cat > .env <<EOF
POSTGRES_PASSWORD=$(r)
PG_APP_PASSWORD=$(r)
PG_BACKUP_PASSWORD=$(r)
MYSQL_ROOT_PASSWORD=$(r)
MY_APP_PASSWORD=$(r)
MY_BACKUP_PASSWORD=$(r)
PGCRYPTO_KEY=$(r 32)
EOF
echo "[gen_secrets] .env generado:"
ls -l .env
echo "[gen_secrets] variables definidas (valores ocultos):"
cut -d= -f1 .env
