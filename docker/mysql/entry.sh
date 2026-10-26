#!/bin/bash
# Copia los certificados con propietario mysql y deja ficheros de opciones de cliente
# (root y backup) con permisos 0600 dentro del contenedor, para no pasar contraseñas por la línea de comandos.
set -euo pipefail
D=/etc/mysql-certs
install -d -o mysql -g mysql -m 750 "$D" /var/log/mysql
chown mysql:mysql /var/log/mysql
install -o mysql -g mysql -m 600 /certs-src/mysql.key "$D/server.key"
install -o mysql -g mysql -m 644 /certs-src/mysql.crt "$D/server.crt"
install -o mysql -g mysql -m 644 /certs-src/ca.crt "$D/ca.crt"
umask 077
printf '[client]\nuser=root\npassword=%s\n' "$MYSQL_ROOT_PASSWORD" > /root/.my.cnf
printf '[client]\nuser=backup\npassword=%s\n' "$MY_BACKUP_PASSWORD" > /root/backup.cnf
exec docker-entrypoint.sh "$@"
