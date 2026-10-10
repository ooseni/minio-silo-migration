#!/usr/bin/env bash
# Start a lab Compose project and wait until it is healthy.
# Usage: scripts/up.sh minio-single        (TLS=1 scripts/up.sh minio-single for HTTPS)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

name="${1:?usage: scripts/up.sh <project>}"
dir="$(project_dir "$name")"
[[ -f "$dir/.env" ]] || die "compose/$name/.env is missing: copy .env.example to .env and set the values"
grep -q 'CHANGE_ME' "$dir/.env" && die "compose/$name/.env still has CHANGE_ME placeholders"
if [[ "${TLS:-0}" == "1" ]]; then
  [[ -f "$LAB_CERTS_DIR/$name/public.crt" ]] || die "no certificates: run scripts/tls-gen.sh $name first"
fi

ensure_network
# Create the bind-mount directory as you, before Docker creates it as root.
mkdir -p "$LAB_DATA_DIR/$name/data"

start=$(date +%s)
lab_compose "$name" up -d --wait --wait-timeout 180
echo "$name healthy after $(( $(date +%s) - start ))s"
lab_compose "$name" ps
