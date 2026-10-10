# syntax=docker/dockerfile:1
#
# MinIO server built from the last open-source release tag.
#
# Upstream published RELEASE.2025-10-15T17-29-55Z as source only and its
# release notes tell container users to build the image themselves. This
# mirrors upstream's Dockerfile.release layout (ubi-micro runtime, minio + mc
# in /usr/bin, same entrypoint) but compiles minio from the pinned tag
# instead of downloading it from dl.min.io, which no longer serves it.
#
# Build: scripts/build-minio-image.sh (reads versions.env)

FROM docker.io/library/golang:1.24.8-alpine@sha256:3d78beb141d98f42337f1252ecf2a5f20374109929a4c3f6817f9e4179cc0ae5 AS build

ARG MINIO_RELEASE
ARG MINIO_COMMIT
ARG MC_RELEASE
ARG TARGETARCH=amd64
# MinIO's release-signing key, from upstream Dockerfile.release.
ARG MINISIGN_PUBKEY=RWTx5Zr1tiHQLwG9keckT0c45M3AGeHD6IvimQHpyRywVWGbP1aVSGav

ENV CGO_ENABLED=0 \
    GOTOOLCHAIN=local

RUN apk add --no-cache ca-certificates curl git && \
    go install aead.dev/minisign/cmd/minisign@v0.2.1

WORKDIR /src

# Source: exact tag, and fail if the tag no longer points at the pinned commit.
RUN git clone --quiet --depth 1 --branch "${MINIO_RELEASE}" https://github.com/minio/minio.git . && \
    test "$(git rev-parse HEAD)" = "${MINIO_COMMIT}"

# Same flags as upstream's release build: version stamped from the tag.
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    version="${MINIO_RELEASE#RELEASE.}" && \
    ldflags="$(MINIO_RELEASE=RELEASE go run buildscripts/gen-ldflags.go "${version}")" && \
    go build -tags kqueue -trimpath -ldflags "${ldflags}" -o /out/minio . && \
    sha256sum /out/minio | tee /out/minio.sha256sum

# mc: official binary from the GitHub release, verified by signature and checksum.
RUN base="https://github.com/minio/mc/releases/download/${MC_RELEASE}/mc.linux-${TARGETARCH}.${MC_RELEASE}" && \
    curl -fsSL -o /out/mc "${base}" && \
    curl -fsSL -o /tmp/mc.minisig "${base}.minisig" && \
    curl -fsSL -o /tmp/mc.sha256sum "${base}.sha256sum" && \
    minisign -Vqm /out/mc -x /tmp/mc.minisig -P "${MINISIGN_PUBKEY}" && \
    echo "$(cut -d' ' -f1 /tmp/mc.sha256sum)  /out/mc" | sha256sum -c - && \
    chmod +x /out/mc /out/minio

FROM registry.access.redhat.com/ubi9/ubi-micro@sha256:7a0454cbd9bd847e8f6a63b6f0254a6efbeb6e0ed71a5d824a4f6cccbe626650

ARG MINIO_RELEASE
ARG MINIO_COMMIT

LABEL org.opencontainers.image.title="minio" \
      org.opencontainers.image.version="${MINIO_RELEASE}" \
      org.opencontainers.image.revision="${MINIO_COMMIT}" \
      org.opencontainers.image.source="https://github.com/ooseni/minio-silo-migration" \
      org.opencontainers.image.description="MinIO ${MINIO_RELEASE} built from source for the MinIO to Silo migration lab" \
      org.opencontainers.image.licenses="AGPL-3.0-only"

ENV MINIO_CONFIG_ENV_FILE=config.env \
    MC_CONFIG_DIR=/tmp/.mc

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /out/minio /out/minio.sha256sum /out/mc /usr/bin/
COPY --from=build /src/LICENSE /src/CREDITS /licenses/
COPY --from=build /src/dockerscripts/docker-entrypoint.sh /usr/bin/docker-entrypoint.sh

EXPOSE 9000
VOLUME ["/data"]

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["minio"]
