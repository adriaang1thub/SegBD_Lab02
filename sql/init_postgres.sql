-- Datos del baseline inseguro (PostgreSQL). Contraseñas en claro: SOLO LABORATORIO.
CREATE TABLE usuarios (
  id       SERIAL PRIMARY KEY,
  nombre   VARCHAR(50)  NOT NULL UNIQUE,
  email    VARCHAR(100) NOT NULL,
  password VARCHAR(100) NOT NULL,
  rol      VARCHAR(20)  NOT NULL DEFAULT 'cliente'
);
CREATE TABLE productos (
  id     SERIAL PRIMARY KEY,
  nombre VARCHAR(80)    NOT NULL,
  precio NUMERIC(10,2)  NOT NULL,
  stock  INT            NOT NULL DEFAULT 0
);
CREATE TABLE comentarios (
  id      SERIAL PRIMARY KEY,
  usuario VARCHAR(50)  NOT NULL,
  texto   VARCHAR(500) NOT NULL,
  fecha   TIMESTAMP    NOT NULL DEFAULT now()
);

INSERT INTO usuarios (nombre, email, password, rol) VALUES
  ('admin', 'admin@tienda.lab',  'Adm1n!2026', 'admin'),
  ('alice', 'alice@correo.lab',  'alice123',   'cliente'),
  ('bob',   'bob@correo.lab',    'bob123',     'cliente'),
  ('carol', 'carol@correo.lab',  'carol123',   'cliente');

INSERT INTO productos (nombre, precio, stock) VALUES
  ('Teclado mecánico', 89.90, 25),
  ('Ratón inalámbrico', 29.90, 60),
  ('Monitor 27', 279.00, 10);

INSERT INTO comentarios (usuario, texto) VALUES
  ('alice', 'Muy buen teclado'),
  ('bob',   'El ratón llegó tarde');
