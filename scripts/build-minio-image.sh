#!/usr/bin/env bash
# Build the MinIO image from the pinned source tag (see versions.env).
# Usage: scripts/build-minio-image.sh [--push]
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../versions.env
source "$root/versions.env"

start=$(date +%s)
docker build \
  --build-arg MINIO_RELEASE="$MINIO_RELEASE" \
  --build-arg MINIO_COMMIT="$MINIO_COMMIT" \
  --build-arg MC_RELEASE="$MC_RELEASE" \
  -t "$MINIO_IMAGE" \
  "$root/images/minio"
echo "Build time: $(( $(date +%s) - start ))s"

docker run --rm --entrypoint minio "$MINIO_IMAGE" --version
docker run --rm --entrypoint cat "$MINIO_IMAGE" /usr/bin/minio.sha256sum
docker image inspect "$MINIO_IMAGE" --format 'Image ID: {{.Id}}  Size: {{.Size}} bytes'

if [[ "${1:-}" == "--push" ]]; then
  docker push "$MINIO_IMAGE"
  docker buildx imagetools inspect "$MINIO_IMAGE" | awk '/^Digest:/{print "Registry digest: " $2}'
fi
