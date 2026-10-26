"""Comprobaciones automáticas desde dentro de la red backend (las usa scripts/verify.sh)."""
import os
import sys

import psycopg
import pymysql

import seguro

CA = seguro.CA
PG_HOST = os.getenv("PG_HOST", "postgres")
MY_HOST = os.getenv("MY_HOST", "mysql")
resultados = []


def check(nombre, fn):
    try:
        ok, detalle = fn()
    except Exception as e:  # noqa: BLE001
        ok, detalle = False, f"{type(e).__name__}: {e}"
    detalle = str(detalle).strip().splitlines()[0][:110]
    print(f"[{'PASS' if ok else 'FAIL'}] {nombre} -> {detalle}")
    resultados.append(ok)


def debe_fallar(fn, *pistas):
    try:
        fn()
    except Exception as e:  # noqa: BLE001
        msg = str(e).strip().splitlines()[0] if str(e).strip() else type(e).__name__
        msg = msg.split("failed: ")[-1]
        return any(p.lower() in str(e).lower() for p in pistas), msg
    return False, "operación aceptada (no debería)"


def pg(**kw):
    base = dict(host=PG_HOST, dbname="tienda", user=os.environ["PG_APP_USER"],
                password=os.environ["PG_APP_PASSWORD"], sslmode="verify-full",
                sslrootcert=CA, connect_timeout=5, autocommit=True)
    base.update(kw)
    return psycopg.connect(**base)


def my(**kw):
    base = dict(host=MY_HOST, port=int(os.getenv("MY_PORT", "3306")), user=os.environ["MY_APP_USER"], password=os.environ["MY_APP_PASSWORD"],
                database="tienda", ssl_ca=CA, ssl_verify_cert=True, ssl_verify_identity=True,
                connect_timeout=5, autocommit=True)
    base.update(kw)
    return pymysql.connect(**base)


def q(conn, sql, params=()):
    cur = conn.cursor()
    cur.execute(sql, params)
    return cur.fetchall()


# ------------------------------------------------------------------ PostgreSQL
check("PG  superusuario 'postgres' por red rechazado (pg_hba)",
      lambda: debe_fallar(lambda: pg(user="postgres", password="postgres", sslmode="require"), "rejects"))
check("PG  appuser sin contraseña rechazado",
      lambda: debe_fallar(lambda: pg(password=""), "password"))
check("PG  appuser sin TLS rechazado",
      lambda: debe_fallar(lambda: pg(sslmode="disable"), "no encryption"))


def pg_tls():
    r = q(pg(), "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid()")[0]
    return r[0] is True and r[1] in ("TLSv1.2", "TLSv1.3"), f"ssl={r[0]} {r[1]} {r[2]}"


check("PG  TLS negociado y certificado verificado (verify-full)", pg_tls)


def pg_no_super():
    r = q(pg(), "SELECT rolsuper, rolcreaterole, rolcreatedb FROM pg_roles WHERE rolname = current_user")[0]
    return not any(r), f"rolsuper={r[0]} createrole={r[1]} createdb={r[2]}"


check("PG  appuser no es superusuario", pg_no_super)
check("PG  appuser no puede leer password_hash",
      lambda: debe_fallar(lambda: q(pg(), "SELECT password_hash FROM usuarios"), "permission denied"))
check("PG  appuser no puede crear tablas",
      lambda: debe_fallar(lambda: q(pg(), "CREATE TABLE intruso (i int)"), "permission denied"))


def pg_sqli():
    c = pg()
    filas = q(c, "SELECT id, nombre FROM usuarios WHERE nombre = %s", ("' OR '1'='1",))
    rechazo, _ = debe_fallar(lambda: seguro.buscar(c, "' OR '1'='1"), "nombre")
    return len(filas) == 0 and rechazo, f"parametrizada={len(filas)} filas; validación=rechaza"


check("PG  SQLi neutralizada (parámetros + validación)", pg_sqli)


def pg_cifrado():
    cols = dict(q(pg(), "SELECT attname, format_type(atttypid, atttypmod) FROM pg_attribute "
                        "WHERE attrelid = 'usuarios'::regclass AND attnum > 0 AND NOT attisdropped"))
    return "email" not in cols and cols.get("email_enc") == "bytea", f"columnas={sorted(cols)}"


check("PG  email cifrado en reposo (solo email_enc bytea)", pg_cifrado)


def pg_clave():
    c = pg()
    ok = q(c, "SELECT pgp_sym_decrypt(email_enc, %s) FROM usuarios WHERE id = 1",
           (os.environ["PGCRYPTO_KEY"],))[0][0]
    mala, msg = debe_fallar(lambda: q(c, "SELECT pgp_sym_decrypt(email_enc, %s) FROM usuarios WHERE id = 1",
                                      ("clave_incorrecta",)), "wrong key")
    return ok.endswith(".lab") and mala, f"clave correcta={ok}; clave incorrecta={msg}"


check("PG  descifrado solo con la clave correcta", pg_clave)

# ------------------------------------------------------------------ MySQL
check("MY  root remoto sin contraseña rechazado",
      lambda: debe_fallar(lambda: my(user="root", password=""), "access denied"))
check("MY  app sin TLS rechazado",
      lambda: debe_fallar(lambda: my(ssl_ca=None, ssl_verify_cert=None, ssl_verify_identity=None,
                                     ssl_disabled=True), "insecure transport", "access denied"))


def my_tls():
    r = dict(q(my(), "SHOW SESSION STATUS WHERE Variable_name IN ('Ssl_version', 'Ssl_cipher')"))
    return r.get("Ssl_version") in ("TLSv1.2", "TLSv1.3"), f"{r.get('Ssl_version')} {r.get('Ssl_cipher')}"


check("MY  TLS negociado y certificado verificado (VERIFY_IDENTITY)", my_tls)
check("MY  app no puede leer password_hash",
      lambda: debe_fallar(lambda: q(my(), "SELECT password_hash FROM usuarios"), "denied"))
check("MY  app no puede borrar tablas",
      lambda: debe_fallar(lambda: q(my(), "DROP TABLE productos"), "denied"))


def my_sqli():
    c = my()
    filas = q(c, "SELECT id, nombre FROM usuarios WHERE nombre = %s", ("' OR '1'='1",))
    rechazo, _ = debe_fallar(lambda: seguro.buscar(c, "' OR '1'='1"), "nombre")
    return len(filas) == 0 and rechazo, f"parametrizada={len(filas)} filas; validación=rechaza"


check("MY  SQLi neutralizada (parámetros + validación)", my_sqli)

sys.exit(0 if all(resultados) else 1)
