#!/usr/bin/env bash
# Run mc from a container on the lab network, with alias "lab" pointing at a project.
# Usage: scripts/mc.sh minio-single admin info lab
#        TLS=1 scripts/mc.sh minio-single ls lab
# MC_IMAGE overrides the client image (default: the MinIO image, which ships mc).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

name="${1:?usage: scripts/mc.sh <project> <mc args...>}"; shift
dir="$(project_dir "$name")"
[[ -f "$dir/.env" ]] || die "compose/$name/.env is missing"
# shellcheck disable=SC1091
set -a; source "$dir/.env"; set +a

scheme=http; tls_args=()
if [[ "${TLS:-0}" == "1" ]]; then
  scheme=https
  tls_args=(-v "$LAB_CERTS_DIR/ca/ca.crt:/lab-ca.crt:ro" -e SSL_CERT_FILE=/lab-ca.crt)
fi

# Credentials go through an env file on a pipe, not the command line, so they
# don't show up in `ps` or the container's inspect output.
docker run --rm -i --network "$LAB_NETWORK" --user "$LAB_UID:$LAB_GID" \
  -e MC_CONFIG_DIR=/tmp/.mc "${tls_args[@]}" \
  --env-file <(printf 'MC_HOST_lab=%s://%s:%s@%s:9000\n' "$scheme" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" "$name") \
  --entrypoint mc "${MC_IMAGE:-$MINIO_IMAGE}" "$@"
