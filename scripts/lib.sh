#!/usr/bin/env bash
# Shared helpers for the lab scripts. Source it, don't run it.

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LAB_ROOT
# shellcheck source=../versions.env
set -a; source "$LAB_ROOT/versions.env"; set +a

export LAB_UID="${LAB_UID:-$(id -u)}"
export LAB_GID="${LAB_GID:-$(id -g)}"
export LAB_DATA_DIR="${LAB_DATA_DIR:-$LAB_ROOT/lab-data}"
export LAB_CERTS_DIR="${LAB_CERTS_DIR:-$LAB_ROOT/certs}"

die() { echo "ERROR: $*" >&2; exit 1; }

# project_dir NAME -> compose/NAME, after checking it exists.
project_dir() {
  local dir="$LAB_ROOT/compose/${1:?project name required, e.g. minio-single}"
  [[ -f "$dir/compose.yaml" ]] || die "no Compose project at compose/$1"
  echo "$dir"
}

# lab_compose NAME ARGS... -> docker compose with versions.env, the project's
# .env and, when TLS=1, the project's TLS overlay.
lab_compose() {
  local name="$1"; shift
  local dir; dir="$(project_dir "$name")"
  local files=(-f "$dir/compose.yaml")
  if [[ "${TLS:-0}" == "1" ]]; then
    [[ -f "$dir/compose.tls.yaml" ]] || die "compose/$name has no TLS overlay"
    files+=(-f "$dir/compose.tls.yaml")
  fi
  local envs=(--env-file "$LAB_ROOT/versions.env")
  [[ -f "$dir/.env" ]] && envs+=(--env-file "$dir/.env")
  docker compose --project-directory "$dir" "${envs[@]}" "${files[@]}" "$@"
}

ensure_network() {
  if ! docker network inspect "$LAB_NETWORK" >/dev/null 2>&1; then
    docker network create --driver bridge --label lab=minio-silo-migration "$LAB_NETWORK" >/dev/null
    echo "Created network $LAB_NETWORK"
  fi
}
