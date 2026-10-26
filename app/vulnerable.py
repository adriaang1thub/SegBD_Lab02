"""App VULNERABLE (solo laboratorio).

Fallos deliberados:
  * Concatena la entrada del usuario dentro del SQL (f-strings) -> SQLi en SELECT e INSERT
  * Conecta como superusuario (postgres / root sin contraseña)
  * Sin TLS y con credenciales escritas en el código

Uso:  python vulnerable.py --db pg|my buscar NOMBRE
      python vulnerable.py --db pg|my comentar USUARIO TEXTO
      python vulnerable.py --db pg|my comentarios
      python vulnerable.py --db pg|my productos listar|crear NOMBRE PRECIO STOCK|actualizar ID PRECIO|borrar ID
"""
import argparse
import os

import psycopg2
import pymysql


def conectar(db):
    if db == "pg":
        conn = psycopg2.connect(host=os.getenv("PG_HOST", "localhost"), dbname="tienda",
                                user="postgres", password="postgres")
        conn.autocommit = True
        return conn
    return pymysql.connect(host=os.getenv("MY_HOST", "localhost"), port=int(os.getenv("MY_PORT", "3306")),
                           user="root", password="",
                           database="tienda", autocommit=True)


def ejecutar(conn, sql):
    print(f"[SQL] {sql}")
    cur = conn.cursor()
    cur.execute(sql)                       # SQL construido por concatenación
    try:
        filas = cur.fetchall()
    except psycopg2.ProgrammingError:      # la última sentencia no devuelve filas
        filas = None
    if filas:
        for f in filas:
            print("  " + " | ".join(str(x) for x in f))
    else:
        extra = f"; filas afectadas: {cur.rowcount}" if cur.rowcount >= 0 else ""
        print(f"  (sin filas devueltas{extra})")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--db", choices=["pg", "my"], default="pg")
    p.add_argument("accion")
    p.add_argument("args", nargs="*")
    a = p.parse_args()
    conn = conectar(a.db)

    if a.accion == "buscar":
        nombre = a.args[0]
        ejecutar(conn, f"SELECT id, nombre FROM usuarios WHERE nombre = '{nombre}'")
    elif a.accion == "comentar":
        usuario, texto = a.args[0], a.args[1]
        ejecutar(conn, f"INSERT INTO comentarios (usuario, texto) VALUES ('{usuario}', '{texto}')")
    elif a.accion == "comentarios":
        ejecutar(conn, "SELECT id, usuario, texto FROM comentarios ORDER BY id")
    elif a.accion == "productos":
        op = a.args[0]
        if op == "listar":
            ejecutar(conn, "SELECT id, nombre, precio, stock FROM productos ORDER BY id")
        elif op == "crear":
            n, pr, st = a.args[1:4]
            ejecutar(conn, f"INSERT INTO productos (nombre, precio, stock) VALUES ('{n}', {pr}, {st})")
        elif op == "actualizar":
            pid, pr = a.args[1:3]
            ejecutar(conn, f"UPDATE productos SET precio = {pr} WHERE id = {pid}")
        elif op == "borrar":
            ejecutar(conn, f"DELETE FROM productos WHERE id = {a.args[1]}")
    else:
        p.error("acción desconocida")


if __name__ == "__main__":
    main()
