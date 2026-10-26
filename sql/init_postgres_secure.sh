#!/bin/bash
# Inicialización del PostgreSQL endurecido: esquema, datos, extensiones y roles de mínimo privilegio.
# Las contraseñas llegan por variables de entorno (.env); nunca se escriben en el repositorio.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname tienda \
     -v app_pass="$PG_APP_PASSWORD" -v bkp_pass="$PG_BACKUP_PASSWORD" <<'SQL'
-- Que las sentencias con contraseñas de rol no queden en el log de auditoría
SET pgaudit.log = 'none';

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pgaudit;

CREATE TABLE usuarios (
  id            SERIAL PRIMARY KEY,
  nombre        VARCHAR(50)  NOT NULL UNIQUE,
  email         VARCHAR(100) NOT NULL,          -- se cifra en la fase F5 (pgcrypto)
  password_hash TEXT         NOT NULL,          -- bcrypt (crypt + gen_salt('bf'))
  rol           VARCHAR(20)  NOT NULL DEFAULT 'cliente'
);
CREATE TABLE productos (
  id     SERIAL PRIMARY KEY,
  nombre VARCHAR(80)   NOT NULL,
  precio NUMERIC(10,2) NOT NULL CHECK (precio > 0),
  stock  INT           NOT NULL DEFAULT 0 CHECK (stock >= 0)
);
CREATE TABLE comentarios (
  id      SERIAL PRIMARY KEY,
  usuario VARCHAR(50)  NOT NULL,
  texto   VARCHAR(500) NOT NULL,
  fecha   TIMESTAMP    NOT NULL DEFAULT now()
);

INSERT INTO usuarios (nombre, email, password_hash, rol) VALUES
  ('admin', 'admin@tienda.lab', crypt('Adm1n!2026', gen_salt('bf', 10)), 'admin'),
  ('alice', 'alice@correo.lab', crypt('alice123',   gen_salt('bf', 10)), 'cliente'),
  ('bob',   'bob@correo.lab',   crypt('bob123',     gen_salt('bf', 10)), 'cliente'),
  ('carol', 'carol@correo.lab', crypt('carol123',   gen_salt('bf', 10)), 'cliente');
INSERT INTO productos (nombre, precio, stock) VALUES
  ('Teclado mecánico', 89.90, 25), ('Ratón inalámbrico', 29.90, 60), ('Monitor 27', 279.00, 10);
INSERT INTO comentarios (usuario, texto) VALUES
  ('alice', 'Muy buen teclado'), ('bob', 'El ratón llegó tarde');

-- Roles de mínimo privilegio
CREATE ROLE appuser LOGIN PASSWORD :'app_pass'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 20;
CREATE ROLE backup_user LOGIN PASSWORD :'bkp_pass' NOSUPERUSER NOCREATEDB NOCREATEROLE;
GRANT pg_read_all_data TO backup_user;              -- solo lectura, para pg_dump

REVOKE ALL ON DATABASE tienda FROM PUBLIC;
GRANT CONNECT ON DATABASE tienda TO appuser, backup_user;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO appuser;

GRANT SELECT (id, nombre) ON usuarios TO appuser;   -- nunca password_hash ni email
GRANT SELECT, INSERT, UPDATE, DELETE ON productos TO appuser;
GRANT SELECT, INSERT ON comentarios TO appuser;
GRANT USAGE ON SEQUENCE productos_id_seq, comentarios_id_seq TO appuser;
SQL
