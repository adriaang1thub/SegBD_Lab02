#!/bin/bash
# Usuarios de mínimo privilegio en MySQL. Contraseñas desde el entorno (.env).
# app: solo desde la subred interna, TLS obligatorio y permisos por tabla/columna.
# backup: solo local (socket) y solo lectura para mysqldump.
if declare -F docker_process_sql >/dev/null; then
  RUN=(docker_process_sql --database=tienda)
else
  RUN=(mysql --protocol=socket -uroot --password="$MYSQL_ROOT_PASSWORD" tienda)
fi
"${RUN[@]}" <<SQL
CREATE USER 'app'@'172.30.10.%' IDENTIFIED BY '${MY_APP_PASSWORD}' REQUIRE SSL;
GRANT SELECT (id, nombre) ON tienda.usuarios TO 'app'@'172.30.10.%';
GRANT SELECT, INSERT, UPDATE, DELETE ON tienda.productos TO 'app'@'172.30.10.%';
GRANT SELECT, INSERT ON tienda.comentarios TO 'app'@'172.30.10.%';

CREATE USER 'backup'@'localhost' IDENTIFIED BY '${MY_BACKUP_PASSWORD}';
GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES ON tienda.* TO 'backup'@'localhost';
SQL
