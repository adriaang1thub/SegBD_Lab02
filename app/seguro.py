"""App ENDURECIDA.

Contramedidas:
  * Consultas parametrizadas: psycopg 3 (parámetros enlazados en el servidor) y PyMySQL (%s escapado)
  * Validación de entrada por lista blanca (tipo, longitud y patrón) antes de tocar la BD
  * Usuarios de aplicación sin privilegios de superusuario (appuser / app), con permisos por columna
  * Credenciales por variables de entorno (fichero .env fuera del repositorio)
  * TLS obligatorio y verificado contra la CA propia (verify-full / VERIFY_IDENTITY)
  * El email se guarda cifrado con pgcrypto; la clave sólo la conoce la app (PGCRYPTO_KEY)

Uso: igual que vulnerable.py, más:
      python seguro.py --db pg perfil ID       (descifra el email con pgcrypto)
      python seguro.py --db pg|my tls          (muestra la negociación TLS)
      python seguro.py --db pg|my sin-tls      (intenta conectar sin TLS: debe fallar)
      python seguro.py --db pg|my lento        (consulta de 2 s para el slow log)
"""
import argparse
import os
import re
import sys

import psycopg
import pymysql

CA = os.getenv("TLS_CA_FILE", "/certs/ca.crt")

NOMBRE_RE = re.compile(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{1,50}$")
PRODUCTO_RE = re.compile(r"^[\wÁÉÍÓÚÜÑáéíóúüñ .-]{1,80}$")


class EntradaNoValida(ValueError):
    pass


# ------------------------------------------------------------------ validación (lista blanca)
def v_nombre(s):
    if not NOMBRE_RE.fullmatch(s or ""):
        raise EntradaNoValida("nombre: solo letras, 1-50 caracteres")
    return s


def v_texto(s):
    if not s or len(s) > 200 or any(ord(c) < 32 for c in s):
        raise EntradaNoValida("texto: 1-200 caracteres imprimibles")
    return s


def v_producto(s):
    if not PRODUCTO_RE.fullmatch(s or ""):
        raise EntradaNoValida("producto: letras, números, espacio, punto o guion (1-80)")
    return s


def v_entero(s, lo, hi, campo):
    if not re.fullmatch(r"\d{1,9}", s or "") or not lo <= int(s) <= hi:
        raise EntradaNoValida(f"{campo}: entero entre {lo} y {hi}")
    return int(s)


def v_precio(s):
    if not re.fullmatch(r"\d{1,6}(\.\d{1,2})?", s or "") or float(s) <= 0:
        raise EntradaNoValida("precio: número positivo con hasta 2 decimales")
    return s


# ------------------------------------------------------------------ conexiones (mínimo privilegio + TLS)
def conectar(db, tls=True):
    if db == "pg":
        return psycopg.connect(
            host=os.getenv("PG_HOST", "postgres"), dbname="tienda",
            user=os.environ["PG_APP_USER"], password=os.environ["PG_APP_PASSWORD"],
            sslmode="verify-full" if tls else "disable", sslrootcert=CA,
            connect_timeout=5, autocommit=True)
    extra = dict(ssl_ca=CA, ssl_verify_cert=True, ssl_verify_identity=True) if tls else dict(ssl_disabled=True)
    return pymysql.connect(
        host=os.getenv("MY_HOST", "mysql"), port=int(os.getenv("MY_PORT", "3306")), database="tienda",
        user=os.environ["MY_APP_USER"], password=os.environ["MY_APP_PASSWORD"],
        autocommit=True, connect_timeout=5, **extra)


def ejecutar(conn, sql, params=(), mostrar=None):
    print(f"[SQL] {sql}   params={mostrar if mostrar is not None else params}")
    cur = conn.cursor()
    cur.execute(sql, params)               # la entrada viaja como parámetro, nunca como código SQL
    filas = cur.fetchall() if cur.description else None
    if filas:
        for f in filas:
            print("  " + " | ".join(str(x) for x in f))
    else:
        print(f"  (sin filas devueltas; filas afectadas: {cur.rowcount})")
    return filas


# ------------------------------------------------------------------ acciones
def buscar(conn, nombre):
    return ejecutar(conn, "SELECT id, nombre FROM usuarios WHERE nombre = %s", (v_nombre(nombre),))


def comentar(conn, usuario, texto):
    return ejecutar(conn, "INSERT INTO comentarios (usuario, texto) VALUES (%s, %s)",
                    (v_nombre(usuario), v_texto(texto)))


def tls_info(db, conn):
    if db == "pg":
        return ejecutar(conn, "SELECT current_user, ssl, version, cipher, bits FROM pg_stat_ssl "
                              "WHERE pid = pg_backend_pid()")
    ejecutar(conn, "SELECT CURRENT_USER()")
    return ejecutar(conn, "SHOW SESSION STATUS WHERE Variable_name IN ('Ssl_version', 'Ssl_cipher')")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--db", choices=["pg", "my"], default="pg")
    p.add_argument("accion")
    p.add_argument("args", nargs="*")
    a = p.parse_args()

    try:
        if a.accion == "sin-tls":
            conectar(a.db, tls=False)
            print("[!] Conexión SIN TLS aceptada (no debería ocurrir)")
            sys.exit(1)

        conn = conectar(a.db)
        if a.accion == "buscar":
            buscar(conn, a.args[0])
        elif a.accion == "comentar":
            comentar(conn, a.args[0], a.args[1])
        elif a.accion == "comentarios":
            ejecutar(conn, "SELECT id, usuario, texto FROM comentarios ORDER BY id")
        elif a.accion == "perfil":
            if a.db != "pg":
                raise EntradaNoValida("el cifrado con pgcrypto solo existe en PostgreSQL")
            ejecutar(conn, "SELECT id, nombre, pgp_sym_decrypt(email_enc, %s) AS email "
                           "FROM usuarios WHERE id = %s",
                     (os.environ["PGCRYPTO_KEY"], v_entero(a.args[0], 1, 10**6, "id")),
                     mostrar=("<PGCRYPTO_KEY oculta>", a.args[0]))
        elif a.accion == "tls":
            tls_info(a.db, conn)
        elif a.accion == "lento":
            ejecutar(conn, "SELECT pg_sleep(2)" if a.db == "pg" else "SELECT SLEEP(2)")
        elif a.accion == "productos":
            op = a.args[0]
            if op == "listar":
                ejecutar(conn, "SELECT id, nombre, precio, stock FROM productos ORDER BY id")
            elif op == "crear":
                ejecutar(conn, "INSERT INTO productos (nombre, precio, stock) VALUES (%s, %s, %s)",
                         (v_producto(a.args[1]), v_precio(a.args[2]), v_entero(a.args[3], 0, 100000, "stock")))
            elif op == "actualizar":
                ejecutar(conn, "UPDATE productos SET precio = %s WHERE id = %s",
                         (v_precio(a.args[2]), v_entero(a.args[1], 1, 10**6, "id")))
            elif op == "borrar":
                ejecutar(conn, "DELETE FROM productos WHERE id = %s", (v_entero(a.args[1], 1, 10**6, "id"),))
        else:
            p.error("acción desconocida")
    except EntradaNoValida as e:
        print(f"[!] Entrada rechazada por validación -> {e}")
        sys.exit(2)
    except (psycopg.Error, pymysql.Error) as e:
        print(f"[!] Rechazado por la base de datos -> {type(e).__name__}: {str(e).strip().splitlines()[0]}")
        sys.exit(3)


if __name__ == "__main__":
    main()
