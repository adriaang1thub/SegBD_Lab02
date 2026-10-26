# SegBD_Lab02 · Hardening de PostgreSQL y MySQL con Python

Laboratorio de la Actividad 2 de *Seguridad en Bases de Datos, Blockchain y Big Data* (UNIR).
Autor: Adrián Vilella Navarro.

> El baseline es **deliberadamente inseguro**. Úsalo solo en una máquina de laboratorio aislada.

## Estructura

```
SegBD_Lab02/
├─ docker-compose.yml            # F0 baseline inseguro (trust, root sin contraseña, puertos publicados)
├─ docker-compose.secure.yml     # F3-F7 stack endurecido
├─ app/
│  ├─ vulnerable.py              # SQL concatenado + superusuarios
│  ├─ seguro.py                  # consultas parametrizadas, validación, TLS, mínimo privilegio
│  ├─ checks.py                  # comprobaciones que usa verify.sh
│  ├─ Dockerfile / requirements.txt
├─ sql/
│  ├─ init_postgres.sql / init_mysql.sql                # datos del baseline
│  ├─ init_postgres_secure.sh                           # esquema, pgcrypto, pgaudit y roles
│  ├─ init_mysql_secure.sql / init_mysql_users.sh       # esquema y usuarios de mínimo privilegio
│  └─ encrypt_email.sql                                 # F5 cifrado del email con pgcrypto
├─ docker/postgres/  (Dockerfile con pgaudit, entry.sh, pg_hba.conf)
├─ docker/mysql/entry.sh
└─ scripts/  gen_certs.sh · gen_secrets.sh · encrypt_at_rest.sh · backup.sh · restore_check.sh · verify.sh
```

## Requisitos

Docker Engine con Compose v2, `openssl` y `nmap` en el host. No hace falta instalar clientes
`psql`/`mysql`: se usan los de las propias imágenes.

## Pasos

```bash
# F0-F2 baseline inseguro
docker compose up -d --build
docker compose exec app python vulnerable.py --db pg buscar "' OR '1'='1"
docker compose down -v

# F3-F4 stack endurecido
./scripts/gen_certs.sh
./scripts/gen_secrets.sh
docker compose -f docker-compose.secure.yml up -d --build
docker compose -f docker-compose.secure.yml exec app python seguro.py --db pg tls

# F5 cifrado en reposo
./scripts/encrypt_at_rest.sh

# F6 copias y restauración
./scripts/backup.sh
./scripts/restore_check.sh

# F7 verificación final
./scripts/verify.sh
```

## Decisiones principales

| Control | PostgreSQL | MySQL |
|---|---|---|
| Autenticación | `scram-sha-256`, `pg_hba.conf` sin `trust` | root solo `localhost`, contraseñas en `.env` |
| Mínimo privilegio | `appuser` sin superusuario y con `SELECT (id, nombre)` en `usuarios`; `backup_user` con `pg_read_all_data` | `app@172.30.10.%` con permisos por columna y `REQUIRE SSL`; `backup@localhost` solo lectura |
| Red | sin `ports:`; red `internal` 172.30.10.0/24 | igual |
| TLS | `ssl=on`, `hostssl` para la app, cliente `verify-full` con CA propia | `require_secure_transport=ON`, cliente `VERIFY_IDENTITY` |
| Auditoría | `pgaudit` (read, write, ddl, role), `log_connections`, consultas > 1 s | `general_log`, `slow_query_log` (> 1 s) |
| Cifrado en reposo | `pgcrypto` (`pgp_sym_encrypt`, AES-256) sobre `email`; clave solo en la app | — (posible ampliación: cifrado de tablespace InnoDB) |
| Backups | `pg_dump -F c` + `pg_restore` en `tienda_restore` | `mysqldump --single-transaction` + restauración |
| Integridad | SHA-256 del fichero + filas y hash de cada tabla | SHA-256 + `CHECKSUM TABLE` |
