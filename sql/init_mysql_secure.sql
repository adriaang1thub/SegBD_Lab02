-- Esquema y datos del MySQL endurecido (contraseñas con hash bcrypt, nunca en claro)
SET NAMES utf8mb4;
USE tienda;
CREATE TABLE usuarios (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  nombre        VARCHAR(50)  NOT NULL UNIQUE,
  email         VARCHAR(100) NOT NULL,
  password_hash CHAR(60)     NOT NULL,
  rol           VARCHAR(20)  NOT NULL DEFAULT 'cliente'
);
CREATE TABLE productos (
  id     INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(80)   NOT NULL,
  precio DECIMAL(10,2) NOT NULL CHECK (precio > 0),
  stock  INT           NOT NULL DEFAULT 0 CHECK (stock >= 0)
);
CREATE TABLE comentarios (
  id      INT AUTO_INCREMENT PRIMARY KEY,
  usuario VARCHAR(50)  NOT NULL,
  texto   VARCHAR(500) NOT NULL,
  fecha   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO usuarios (nombre, email, password_hash, rol) VALUES
  ('admin', 'admin@tienda.lab', '$2b$10$o/nCO7Bq3U7GYH3s8ymeS.rCAlv465Ab/yZncsvafC/Epoes9KAV.', 'admin'),
  ('alice', 'alice@correo.lab', '$2b$10$9oUVijpihg4DqBXxkUgRduCPMxEq0k/6ZfB./pM6dbawgZftT.DK2', 'cliente'),
  ('bob',   'bob@correo.lab',   '$2b$10$Zpr911lw9UeCl1sI9GFJi.VcDAAZ.sDUtYTkausJsbNJHeAzNoo.a', 'cliente'),
  ('carol', 'carol@correo.lab', '$2b$10$Ker3msRdAlHzvDAUKx4qqewynWYyAGTD91AbiZUuzxNBonJk5zSt.', 'cliente');
INSERT INTO productos (nombre, precio, stock) VALUES
  ('Teclado mecánico', 89.90, 25), ('Ratón inalámbrico', 29.90, 60), ('Monitor 27', 279.00, 10);
INSERT INTO comentarios (usuario, texto) VALUES
  ('alice', 'Muy buen teclado'), ('bob', 'El ratón llegó tarde');
