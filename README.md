# MinIO to Silo migration lab

> **Evaluation project.** This repository is a proof of concept for an internship
> assignment. It evaluates whether a deployment of the last open-source MinIO
> release can move to [Silo](https://silo.pgsty.com/), a community-maintained
> MinIO fork, with zero downtime and no loss of data, versions, tags or
> metadata. Everything runs locally in Docker Compose with synthetic data. It is
> not a production deployment and contains no company data.

The approach is a side-by-side migration by replication: run a Silo cluster
next to MinIO, replicate MinIO to Silo, move clients over through a proxy, and
keep reverse replication for a safe rollback. Silo's own in-place image swap is
measured only as a baseline, because a distributed cluster cannot mix MinIO and
Silo nodes and the swap needs a full stop.

## Links

- Jira Epic: [DEV-916](https://glynac.atlassian.net/browse/DEV-916) (Jira sign-in required)
- Project board: added when the board is created

## Status

✅ done, ⬜ planned. A sub-task under way says so in words.

| Sub-task | Jira | Topic | Status | Write-up |
|---|---|---|---|---|
| ST01 | DEV-917 | Repo, version pins and local Compose lab | ⬜ in progress | [docs/01](docs/01-repo-versions-and-lab/README.md) |
| ST02 | DEV-918 | Test data and verification toolkit | ⬜ | docs/02-test-data-and-verification |
| ST03 | DEV-919 | Replication smoke test and rehearsal | ⬜ | docs/03-replication-rehearsal |
| ST04 | DEV-920 | MinIO feature validation (single node) | ⬜ | docs/04-minio-feature-validation |
| ST05 | DEV-921 | MinIO distributed mode: resilience, healing, expansion | ⬜ | docs/05-minio-distributed-mode |
| ST06 | DEV-922 | MinIO performance baseline | ⬜ | docs/06-minio-performance-baseline |
| ST07 | DEV-923 | Migration design and migration lab | ⬜ | docs/07-migration-design-and-lab |
| ST08 | DEV-924 | Migration part 1: config, replication, backfill | ⬜ | docs/08-migrate-config-replication-backfill |
| ST09 | DEV-925 | Migration part 2: live traffic, failures, parity | ⬜ | docs/09-migrate-live-traffic-and-parity |
| ST10 | DEV-926 | Migration part 3: cutover, rollback, decommission | ⬜ | docs/10-cutover-rollback-decommission |
| ST11 | DEV-927 | In-place swap baseline and mixed binaries | ⬜ | docs/11-in-place-baseline |
| ST12 | DEV-928 | Silo validation and compatibility diff | ⬜ | docs/12-silo-validation-and-compatibility |
| ST13 | DEV-929 | Silo benchmark against the MinIO baseline | ⬜ | docs/13-silo-performance-comparison |
| ST14 | DEV-930 | Security, licence, maintenance and CVE review | ⬜ | docs/14-security-licence-review |
| ST15 | DEV-931 | Capability matrix, final report, runbook | ⬜ | docs/15-final-report-and-runbook |

## Versions under test

All pins live in [`versions.env`](versions.env). Images are pinned by immutable
`RELEASE.*` tag and digest, never `latest`.

| Component | Version | Source |
|---|---|---|
| MinIO server | `RELEASE.2025-10-15T17-29-55Z` | Built from source ([`images/minio`](images/minio/Dockerfile)), published as `ghcr.io/ooseni/minio` |
| mc (MinIO client) | `RELEASE.2025-08-13T08-35-41Z` | Official signed binary, inside the MinIO image |
| Silo server | `RELEASE.2026-09-16T00-00-00Z` | `docker.io/pgsty/silo` (classic image) |
| mcli (Silo client) | `RELEASE.2026-09-16T00-00-00Z` | `docker.io/pgsty/mc` |
| warp | `v1.3.1` | `docker.io/minio/warp` |

Why MinIO is built from source, and why the classic Silo image was chosen, is
recorded in [docs/01](docs/01-repo-versions-and-lab/README.md).

## Reproduce the lab

Needs Docker Engine with the Compose plugin, git and openssl on Linux (WSL2
works). Keep the repository on a Linux filesystem, not a Windows `/mnt/c` path.

```bash
git clone https://github.com/ooseni/minio-silo-migration.git
cd minio-silo-migration
scripts/lab-check.sh B                 # machine and Docker check against Profile B

docker pull ghcr.io/ooseni/minio:RELEASE.2025-10-15T17-29-55Z
# or build it yourself from the pinned tag: scripts/build-minio-image.sh

cp compose/minio-single/.env.example compose/minio-single/.env
# edit compose/minio-single/.env and replace both CHANGE_ME values

scripts/up.sh minio-single             # creates migration-net, waits until healthy
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9000/minio/health/live
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9000/minio/health/ready
scripts/mc.sh minio-single admin info lab
```

HTTPS with the lab's own certificate authority:

```bash
scripts/tls-gen.sh minio-single        # self-signed CA and server certificate in certs/
TLS=1 scripts/up.sh minio-single
TLS=1 scripts/mc.sh minio-single admin info lab
```

Stop and clean up:

```bash
scripts/down.sh minio-single           # stops containers, keeps the data
scripts/reset.sh minio-single          # DESTRUCTIVE: deletes the project's data
```

> **Never run `docker compose down -v` on a stack whose data you want to keep.**
> `-v` deletes volumes. `scripts/down.sh` never passes it; only
> `scripts/reset.sh` does, after you type the project name to confirm.

## Repository layout

| Path | Contents |
|---|---|
| `versions.env` | Every pinned version and image digest |
| `images/minio/` | Dockerfile that builds MinIO from the last open-source tag |
| `compose/<project>/` | One Compose project per component, all on the shared `migration-net` network |
| `scripts/` | `lab-check`, `up`, `down`, `reset`, `tls-gen`, `mc`, `stats`, `build-minio-image` |
| `docs/NN-*/` | One write-up per sub-task, with `evidence/` and `screenshots/` |
| `docs/_TEMPLATE/` | The write-up template |
| `lab-data/`, `certs/` | Created at run time and git-ignored: drive data and TLS keys |

## Working rules

- Commits go directly to `main`, at least daily, prefixed with the sub-task:
  `ST01: chore: ...`, `ST05: feat(lab): ...`.
- Secrets never enter the repository. `.env` files, keys, certificates, IAM and
  bucket exports and lab data are git-ignored, and gitleaks scans every commit
  (`.pre-commit-config.yaml`) with GitHub secret scanning as a second layer.
- Every PASS or FAIL claim in a write-up links to raw text evidence.
- Large raw results (for example warp output) are not committed: a summary goes
  in the write-up and the raw file is attached to a GitHub release.

## License

This repository's own scripts, Compose files and documentation are released
under the [MIT License](LICENSE). MinIO, mc, warp, Silo and mcli are licensed
under AGPL-3.0 by their authors. They are not vendored here: images are pulled
from their publishers or built from upstream source.
