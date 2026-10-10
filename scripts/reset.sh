#!/usr/bin/env bash
# DESTRUCTIVE: stop a lab project and DELETE all of its data.
# Usage: scripts/reset.sh minio-single [--yes]
#
# WARNING: this runs `docker compose down -v` and removes lab-data/<project>.
# Never run it on a stack whose data you want to keep (for example the
# migration source after seeding). There is no undo.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

name="${1:?usage: scripts/reset.sh <project> [--yes]}"
project_dir "$name" >/dev/null

if [[ "${2:-}" != "--yes" ]]; then
  echo "This deletes every object in '$name' (containers, volumes and lab-data/$name)."
  read -r -p "Type the project name to confirm: " answer
  [[ "$answer" == "$name" ]] || die "not confirmed, nothing deleted"
fi

lab_compose "$name" down -v --remove-orphans
rm -rf "${LAB_DATA_DIR:?}/$name"
echo "$name reset: containers, volumes and lab-data/$name removed"
