#!/usr/bin/env bash
# Create the lab's self-signed CA (once) and a server certificate for a project.
# Usage: scripts/tls-gen.sh minio-single
# Output (git-ignored): certs/ca/ca.{key,crt}
#                       certs/<project>/{public.crt,private.key,CAs/ca.crt}
set -euo pipefail
source "$(dirname "$0")/lib.sh"

name="${1:?usage: scripts/tls-gen.sh <project>}"
ca_dir="$LAB_CERTS_DIR/ca"
out="$LAB_CERTS_DIR/$name"
mkdir -p "$ca_dir" "$out/CAs"
umask 077

if [[ ! -f "$ca_dir/ca.crt" ]]; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
    -keyout "$ca_dir/ca.key" -out "$ca_dir/ca.crt" -days 365 \
    -subj "/CN=minio-silo-lab CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
  chmod 644 "$ca_dir/ca.crt"   # the CA certificate is public; ca.key stays 600
  echo "Created lab CA: certs/ca/ca.crt"
fi

# Names the server answers to: its container name (from other containers on
# the lab network), localhost and 127.0.0.1 (from the host through the port binding).
san="DNS:$name,DNS:localhost,IP:127.0.0.1"
openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
  -keyout "$out/private.key" -out "$out/server.csr" -subj "/CN=$name" 2>/dev/null
openssl x509 -req -in "$out/server.csr" -CA "$ca_dir/ca.crt" -CAkey "$ca_dir/ca.key" \
  -CAcreateserial -out "$out/public.crt" -days 365 \
  -extfile <(printf 'subjectAltName=%s\nextendedKeyUsage=serverAuth\nkeyUsage=critical,digitalSignature\n' "$san") 2>/dev/null
rm -f "$out/server.csr"
cp "$ca_dir/ca.crt" "$out/CAs/ca.crt"
# Readable by the container user (it runs as your UID).
chmod 600 "$out/private.key"; chmod 644 "$out/public.crt" "$out/CAs/ca.crt"

# Relative paths, so evidence files carry no home-directory path.
(cd "$LAB_CERTS_DIR" && openssl verify -CAfile ca/ca.crt "$name/public.crt")
openssl x509 -in "$out/public.crt" -noout -subject -ext subjectAltName -enddate
