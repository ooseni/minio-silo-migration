#!/usr/bin/env bash
# Stop a lab Compose project and KEEP its data.
# Usage: scripts/down.sh minio-single
#
# This never passes -v. `docker compose down -v` deletes named volumes, and
# the lab's data would be gone. To wipe a project on purpose, use scripts/reset.sh.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

name="${1:?usage: scripts/down.sh <project>}"
lab_compose "$name" down --remove-orphans
echo "$name stopped. Data kept in lab-data/$name"
