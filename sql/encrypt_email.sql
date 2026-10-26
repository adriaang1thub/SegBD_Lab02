-- F5. Cifrado en reposo del email con pgcrypto (PGP simétrico, AES-256).
-- La clave llega como variable de psql (:k) por la entrada estándar, no por la línea de comandos.
-- Solo se audita DDL y ROLE en esta sesión: el UPDATE lleva la clave y no debe acabar en el log.
SET pgaudit.log = 'ddl, role';

\echo '--- Antes: email en claro'
SELECT id, nombre, email FROM usuarios ORDER BY id;

BEGIN;
ALTER TABLE usuarios ADD COLUMN email_enc BYTEA;
UPDATE usuarios SET email_enc = pgp_sym_encrypt(email, :'k', 'cipher-algo=aes256');
ALTER TABLE usuarios ALTER COLUMN email_enc SET NOT NULL;
ALTER TABLE usuarios DROP COLUMN email;
GRANT SELECT (email_enc) ON usuarios TO appuser;
COMMIT;

-- DROP COLUMN y UPDATE dejan las versiones antiguas en disco: se reescribe la tabla
VACUUM FULL usuarios;

\echo '--- Después: solo existe email_enc (bytea cifrado)'
SELECT id, nombre, left(encode(email_enc, 'hex'), 40) || '...' AS email_enc_hex,
       octet_length(email_enc) AS bytes
FROM usuarios ORDER BY id;
