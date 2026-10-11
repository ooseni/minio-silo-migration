#!/usr/bin/env bash
# Basic monitoring: one docker stats snapshot of the lab containers plus host load.
# Usage: scripts/stats.sh [output-file]   (prints to stdout and appends to the file if given)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

{
  echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo "load average: $(cut -d' ' -f1-3 /proc/loadavg) | $(free -h | awk '/^Mem:/{print "mem used " $3 " of " $2}')"
  ids=$(docker ps -q --filter "network=$LAB_NETWORK")
  if [[ -n "$ids" ]]; then
    # shellcheck disable=SC2086
    docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}' $ids
  else
    echo "no running containers on $LAB_NETWORK"
  fi
} | tee -a "${1:-/dev/null}"
