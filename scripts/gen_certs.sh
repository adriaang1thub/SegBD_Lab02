#!/usr/bin/env bash
# CA propia de laboratorio + certificados de servidor para PostgreSQL y MySQL (SAN = nombre del servicio)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p certs && cd certs

openssl req -x509 -newkey rsa:4096 -nodes -days 365 -sha256 \
  -keyout ca.key -out ca.crt -subj "/CN=SegBD Lab02 CA" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null

for par in pg:postgres mysql:mysql; do
  f=${par%%:*}; cn=${par##*:}
  openssl req -newkey rsa:2048 -nodes -keyout "$f.key" -out "$f.csr" -subj "/CN=$cn" 2>/dev/null
  printf "subjectAltName=DNS:%s,DNS:localhost\nbasicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\n" "$cn" > "$f.ext"
  openssl x509 -req -in "$f.csr" -CA ca.crt -CAkey ca.key -CAcreateserial -days 365 -sha256 \
    -extfile "$f.ext" -out "$f.crt" 2>/dev/null
  rm -f "$f.csr" "$f.ext"
done
rm -f ca.srl
chmod 600 ./*.key
chmod 644 ./*.crt
echo "[gen_certs] certificados generados en certs/:"
ls -l
openssl verify -CAfile ca.crt pg.crt mysql.crt
