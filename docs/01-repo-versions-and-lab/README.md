# 01. Repo, version pins and local Compose lab

> Jira: DEV-917 | Sub-task ST01 | Status: built, tested and published; awaiting mentor review | Date: 2026-10-11

## Goal

Create the public repository and its safeguards, pin every version under test
with a digest or checksum, decide how to obtain the last open-source MinIO
release, and bring up a MinIO single node on a bind-mounted local volume that
is healthy, keeps its data across restarts, and works over HTTPS. Record the
machine, the profile and the test matrix that the later sub-tasks follow.

## Environment

| Item | Value |
|---|---|
| MinIO image | `ghcr.io/ooseni/minio:RELEASE.2025-10-15T17-29-55Z`, registry digest `sha256:0a683d8646a28e03f3d7825c66b2eb53786b6c1c4f74c02610b1f6bca336d8b9`, built from source, minio binary SHA-256 `7619daa8b997b3aaf042d04bc49e125d4735143425e110a479bd0b99c6155db4` |
| mc (in the MinIO image) | `RELEASE.2025-08-13T08-35-41Z`, SHA-256 `01f866e9c5f9b87c2b09116fa5d7c06695b106242d829a8bb32990c00312e891` (matches the official release file) |
| Silo image | `docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z@sha256:635197cb9f36d01bee221d34d1c7d7960f6a95c48b0b6c01d99cd13bdae51a46` |
| mcli image | `docker.io/pgsty/mc:RELEASE.2026-09-16T00-00-00Z@sha256:cfc83108c3abb371f8fb84d99c1fdc88f8c237e022409b0081fb7c0a3be634dd` |
| warp image | `docker.io/minio/warp:v1.3.1@sha256:72ae1b02216b51bd102b73a6923b597c092a5acc7a655c936c2f31bee897a7c5` |
| Docker / Compose | Engine 29.8.2 / Compose 5.6.0 (the v2+ `docker compose` plugin), cgroup v2 |
| OS | Ubuntu 26.04.1 LTS on WSL2 (kernel 6.18.40.1), Windows 11 Pro host |
| Local machine | Intel Core i7-3520M (2 cores, 4 threads), 11.9 GB RAM on the host of which WSL may use 6.8 GB plus 4 GB swap, Kingston 240 GB SATA SSD with about 31 GB free |
| Filesystem | ext4 (the WSL virtual disk), lab data never on a `/mnt/c` Windows path |
| Topology | Single node, 1 drive, bind-mounted directory |
| Compose limits | 1 CPU, 1 GiB memory for `minio-single` |
| Date | 2026-10-11 |

All of it is in [`evidence/versions.txt`](evidence/versions.txt) and
[`evidence/lab-check.txt`](evidence/lab-check.txt).

## Decisions

### D1. How we obtain the last open-source MinIO: build it from source

| Finding (2026-10-11) | Evidence |
|---|---|
| `github.com/minio/minio` is archived (last push 2026-04-24) | `evidence/versions.txt` |
| The newest release, `RELEASE.2025-10-15T17-29-55Z` (commit `9e49d5e7a648`), has **0 binary assets**. Its notes fix GHSA-jjjj-jwhf-8rgr (privilege escalation via session policy bypass in service accounts and STS) and tell container users to build the image themselves | `evidence/versions.txt` |
| The previous release, `RELEASE.2025-09-07T16-13-09Z`, still has signed binaries on GitHub but lacks that fix | `evidence/versions.txt` |
| No official image can be pulled anonymously: `docker.io/minio/minio` no longer exists and `quay.io/minio/minio` returns 401. `docker.io/minio/mc` is gone too | `evidence/versions.txt` |

The ticket's assumption is confirmed: `RELEASE.2025-10-15T17-29-55Z` is the last
open-source release, and it exists only as source. We build it with
[`images/minio/Dockerfile`](../../images/minio/Dockerfile):

- the source is cloned at the tag, and the build fails if the tag no longer points at commit `9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a`;
- the version is stamped with upstream's own `buildscripts/gen-ldflags.go`, so `minio --version` reports `RELEASE.2025-10-15T17-29-55Z (commit-id=9e49d5e7...)`;
- the toolchain (`golang:1.24.8-alpine`, the version in the tag's `go.mod`) and the runtime base (`ubi9/ubi-micro`, as upstream used) are pinned by digest;
- `mc` is the official `RELEASE.2025-08-13T08-35-41Z` binary, verified against MinIO's minisign key and SHA-256 during the build;
- the image is published as a public package at `ghcr.io/ooseni/minio`, linked to this repository, in a registry we control, and the Dockerfile in this repo can rebuild it at any time.

Fallback, not used: the signed `RELEASE.2025-09-07T16-13-09Z` binary. It would
put a known privilege-escalation bug in the baseline.

### D2. Silo image variant: classic, not distroless

| | Classic `pgsty/silo:RELEASE...` | Distroless `pgsty/silo:RELEASE...-distroless` |
|---|---|---|
| Contents | `silo`, `mcli` (with an `mc` alias), static `curl`, shell entrypoint | `silo` binary only, no shell, no `mc`, no `curl` |
| Healthcheck | `mc ready local`, the same probe our MinIO image uses | Baked-in `silo healthcheck ready` |
| Size (amd64, compressed) | 56.5 MB | 34.7 MB |
| Status | Default | Pilot ("becomes the recommended default later") |

We use the classic image because the Epic requires comparable conditions: both
products then run the same healthcheck, the same `server /data` command and the
same `--certs-dir` layout, and a shell is available for debugging and failure
injection. The distroless image can be tried in ST12 as a Silo-only extra.

### D3. Large raw result files: summaries in the repo, raw files as release assets

No Git LFS. Raw text evidence for every PASS or FAIL stays in each sub-task's
`evidence/` folder. Anything over 1 MB is blocked by the pre-commit
`check-added-large-files` hook; large raw output (warp results, fio JSON) is
attached to a GitHub release for that sub-task and linked from the write-up.
Reason: LFS needs every cloner to install `git-lfs` and has storage and
bandwidth quotas, while release assets are free to download and don't make
clones heavier.

### D4. Basic monitoring: `docker stats` now, Prometheus and Grafana in ST04

[`scripts/stats.sh`](../../scripts/stats.sh) records a `docker stats` snapshot
of every container on `migration-net` plus host load and memory. Prometheus and
Grafana (optional in the ticket) are deferred to ST04, which tests the metrics
endpoint anyway, to keep this machine's 6.8 GB WSL memory free.

### D5. Profile: below Profile B, run at reduced scale

| | Profile B (fallback) | This machine |
|---|---|---|
| CPU | 8 cores | 4 logical CPUs (2 cores) |
| RAM | 16 GB | 6.8 GB usable by WSL (+4 GB swap), 11.9 GB on the host |
| Free SSD | 100 GB | about 31 GB |

Neither profile is met. The lab runs as **Profile B, reduced**: 4 nodes x 1 drive
per cluster, a synthetic dataset of about 2 GB instead of 5 to 10 GB, tight and
identical Compose limits for MinIO and Silo, heavy stacks one at a time, and all
benchmarks labelled indicative only. The mentor was asked on 2026-10-11 to
confirm this. `scripts/lab-check.sh B` reports the shortfall as warnings.

## Silo compatibility conditions that apply to us

From [silo.pgsty.com/compatibility](https://silo.pgsty.com/compatibility/), read 2026-10-11.

| Condition | Applies? | Why, and where it is tested |
|---|---|---|
| O01 Installation and startup | Yes | We change the image from MinIO to Silo. The data owner (UID 1000), entrypoint, healthcheck and certificate path must keep working. ST07, ST11 |
| O02 Custom authorization policies | Yes | The policy suite uses custom Allow/Deny rules and object ARNs, and the proxy adds a source-IP question. ST04, ST08, ST12 |
| O03 Older auth and notification settings | Check | No OIDC HMAC tokens and no database notifications (webhook only), but TLS and environment-variable startup must be verified on Silo. ST12 |
| O04 Programs relying on old bugs | Yes | Conditional requests (If-Match, If-None-Match), error codes and listing over 1,000 multipart uploads are tested; the workload's retry logic depends on error codes. ST12 |
| O05 Custom clients and administration tools | No | Only standard SDKs, `mc`/`mcli` and aws-cli; no private storage API, Go embedding or Console automation |
| O06 Multi-pool conditions and strict multipart listing | Yes, ST05 and ST12 only | Pool expansion creates a multi-pool cluster where specific-version deletes and conditional writes are checked more strictly. Strict listing stays off (default) |
| O07 Replication, mixed versions and rollback | **Yes, highest impact** | The whole migration is replication from MinIO to Silo with reverse replication for rollback, and ST11 runs mixed binaries. Silo's version matrix says both ends of a replication pair need the repaired build for deletion records (IAM revocations, bucket-config deletions) to be honored; our MinIO source never gets it. ST03, ST08 to ST10 |
| O08 Self-update and upstream online services | Yes, minor | We never use `admin update`, `mcli update` or SUBNET. Scripts must not rely on `mcli update`, which always exits 1 |

Component matrix ([silo.pgsty.com/compatibility/versions](https://silo.pgsty.com/compatibility/versions/)):
Server 20260916 (source `2a4d51406b7e`), mcli 20260916 (`e952aa78f10a`), Console
v2.4.1 (embedded in the server), silo-pkg v3.14.1. Silo states that
compatibility with unmodified upstream MinIO and mc is best effort.

## Prerequisites

Docker Engine with the Compose plugin, git, openssl and gitleaks on Linux or
WSL2. `compose/minio-single/.env` created from `.env.example` with real values.

## Step-by-step procedure

Expected results were written before each step was run.

| # | Command | Expected result | Actual result | PASS/FAIL | Evidence |
|---|---|---|---|---|---|
| 1 | `scripts/lab-check.sh B` | Docker and Compose pass; hardware below Profile B shown as warnings | 0 failures, 3 warnings (CPU, RAM, disk) | PASS | `evidence/lab-check.txt` |
| 2 | `scripts/build-minio-image.sh` | Image builds; `minio --version` shows the pinned release and commit; mc signature and checksum verify | Built in 161 s (Go modules already cached); version and commit correct | PASS | `evidence/minio-image-build.log` |
| 3 | Clean-state check, then `scripts/up.sh minio-single` | No lab containers, networks or volumes; `migration-net` created; healthy within 60 s | Clean; network created; healthy after 7 s | PASS | `evidence/01-up-and-health.txt` |
| 4 | `curl` `/minio/health/live` and `/ready` on 127.0.0.1:9000 | HTTP 200 both; ports bound to 127.0.0.1 only | 200 and 200; `127.0.0.1:9000` and `127.0.0.1:9001` | PASS | `evidence/01-up-and-health.txt` |
| 5 | `scripts/mc.sh minio-single admin info lab` | mc in a container on `migration-net` reaches the server | 1 drive online, version `2025-10-15T17-29-55Z` | PASS | `evidence/02-mc-and-persistence.txt` |
| 6 | Upload a 5 MiB random object, read it back | SHA-256 matches | Match | PASS | `evidence/02-mc-and-persistence.txt` |
| 7 | `docker compose restart`, read back | Healthy again; SHA-256 matches | Healthy after about 8 s; match | PASS | `evidence/02-mc-and-persistence.txt` |
| 8 | `scripts/down.sh` (no `-v`), `scripts/up.sh`, read back | Container removed, data kept; SHA-256 matches | Match | PASS | `evidence/02-mc-and-persistence.txt` |
| 9 | `scripts/tls-gen.sh minio-single`; `TLS=1 scripts/up.sh` | CA and certificate (SAN: minio-single, localhost, 127.0.0.1) verify; healthy over HTTPS | Verified; healthy after 7 s | PASS | `evidence/03-tls.txt` |
| 10 | `curl --cacert` HTTPS health; without CA; plain HTTP | 200 with the CA; certificate error without; HTTP refused | 200; curl exit 60; HTTP 400; TLS 1.3, verify code 0 | PASS | `evidence/03-tls.txt` |
| 11 | `TLS=1 scripts/mc.sh minio-single admin info lab` and `ls` | mc works over HTTPS with the lab CA and fails without it | Works; "certificate signed by unknown authority" without the CA; the 5 MiB object is still listed | PASS | `evidence/03-tls.txt` |
| 12 | `scripts/stats.sh` | CPU and memory per lab container recorded | `minio-single` idle at 72 MiB of 1 GiB | PASS | `evidence/04-docker-stats.txt` |
| 13 | Stage a file with a fake, randomly generated GitHub token and `git commit` | Commit blocked by the gitleaks pre-commit hook, value redacted, HEAD unchanged | Blocked (`github-pat` rule, exit 1), value shown as REDACTED, HEAD unchanged | PASS | `evidence/05-fake-secret-blocked.txt`, `screenshots/fake-secret-blocked.png` |
| 14 | Destroy the lab (reset, network and local image removed), clone the public repo, pull the image, create `.env`, `scripts/up.sh`, then TLS | Healthy from a fresh clone; same image digest; nothing secret in `git status` | Healthy over HTTP after 19 s, over HTTPS after 28 s; digest `sha256:0a683d86...` matches; `git status` clean | PASS | `evidence/06-rebuild-from-clone.txt` |
| 15 | Check GitHub settings without and with the API | Repo and board open without login; MIT recognised; secret scanning and push protection on; package public and linked; 15 issues | All as expected (HTTP 200 for repo and board) | PASS | `evidence/07-github-settings.txt` |

## Results

| Acceptance criterion | Status |
|---|---|
| Public repo opens without login, has the evaluation note, mentor confirms no internal information | Published and opens without login (step 15); mentor confirmation pending |
| Project board with one issue per sub-task, linked both ways; commit workflow agreed | Linked both ways: the [board](https://github.com/users/ooseni/projects/1) has issues #1 to #15, each linking to its Jira sub-task, and each Jira sub-task DEV-917 to DEV-931 has a web link back to its issue (added by the intern on 2026-10-11; the Epic links to the board). Mentor agreement on the commit workflow pending |
| Secret scanning and pre-commit hook active; fake-secret commit blocked (screenshot) | Done: the hook blocks the fake secret (step 13, [screenshot](screenshots/fake-secret-blocked.png) with the shell prompt redacted) and GitHub secret scanning and push protection are enabled (step 15) |
| Versions with digests or checksums; MinIO artifact where we control it; Silo pinned with variant decision; O01 to O08 listed | Done (D1, D2, the table above; image public on GHCR) |
| Machine specs, profile, Docker and Compose versions, volume layout documented | Done (Environment, D5, the layout below) |
| Clean machine to healthy; data survives restart and down/up | Done (steps 3 to 8) |
| Destroy and rebuild from the repo alone, timed; `.env` not committed; `.env.example` placeholders only; TLS with mc over HTTPS | Done: 19 s to a healthy lab from a fresh clone, 28 s with TLS (step 14); `.env` git-ignored, `.env.example` has CHANGE_ME placeholders only |
| Test matrix committed and reviewed by the mentor | Committed as [`docs/test-matrix.md`](../test-matrix.md); review pending |

Volume and directory layout on the host (all git-ignored):

```text
lab-data/
  minio-single/data/        bind-mounted at /data, owned by UID 1000 (the host user)
certs/
  ca/ca.crt, ca.key         lab CA (key mode 600)
  minio-single/             public.crt, private.key, CAs/ca.crt mounted at /certs
```

Rebuild timing note: the 8 s image pull in step 14 may be optimistic, because
Docker's local content store can keep layers after `docker image rm`. The clone
was also placed on a RAM-backed `tmpfs`, which `lab-check` correctly flagged;
real lab data belongs on a disk-backed filesystem.

## Findings

1. **No official MinIO image is pullable any more.** Any Compose file that uses
   `minio/minio` or `quay.io/minio/minio` fails on a clean machine. Severity:
   high for anyone reproducing a MinIO setup; handled by D1.
2. **`docker.io/pgsty/minio` is Silo, not MinIO.** It is Silo's old image name
   (its description reads "SILO - S3-Interface, Libre Object Store"), with tags
   such as `RELEASE.2026-08-04T00-00-00Z`. A baseline built on it would compare
   Silo with Silo. Severity: high for the evaluation's validity.
3. **The last release with ready-made binaries is not the last release.**
   `RELEASE.2025-09-07T16-13-09Z` lacks the GHSA-jjjj-jwhf-8rgr fix that the
   source-only `RELEASE.2025-10-15T17-29-55Z` carries.
4. **MinIO reports the WSL virtual disk size, not the real free space.**
   `mc admin info` shows 956 GiB total, while the virtual disk grows on a host
   drive with about 31 GB free. MinIO will not refuse writes before the host
   disk is full, so watch the host's free space (`scripts/lab-check.sh` reports
   it), not MinIO's capacity figure. Severity: medium for ST02 and the migration.
5. **An abrupt WSL stop can lose recent writes.** During this sub-task the WSL
   VM stopped while a background job ran, and the last git commit's object
   files were left empty (repaired from the intact history, nothing pushed was
   affected). The same can happen to lab data. Keep a WSL terminal open during
   long runs; the repo sets `core.fsync=committed`.
6. **Replication tombstones need Silo's repaired build on both ends (O07).**
   Our MinIO source will never have it, so IAM revocations and bucket-config
   deletions may not carry over during the migration. ST03 and ST08 must test this.

## Assumptions

The ticket asks for answers to the open questions in Section 7 of the Epic. The
Epic description read on 2026-10-11 has no Section 7, so these assumptions
stand in for it until the mentor says otherwise.

| ID | Assumption |
|---|---|
| A1 | The lab runs below Profile B at the reduced scale in D5 (mentor asked 2026-10-11) |
| A2 | NFS is out of scope for every sub-task, including ST06, whose Jira title still mentions it (it was removed from the Epic on 2026-09-28; mentor asked) |
| A3 | Silo stays pinned at `RELEASE.2026-09-16T00-00-00Z` for the whole Epic unless a newer release fixes a security issue that affects the lab; any change is recorded here |
| A4 | Each intern does the whole Epic in their own repository (confirmed by the mentor) |
| A5 | Data and credentials are synthetic and lab-only; credentials are random per machine and never committed |
| A6 | One physical host. Network failures are emulated with `docker network disconnect`, or `tc` in a container with `NET_ADMIN` |
| A7 | The proxy (nginx, HAProxy or Traefik) is chosen in ST07 |
| A8 | SDKs under test: Python boto3 and the MinIO Python SDK, plus mc, mcli and aws-cli |

## Conclusion

ST01's build and test work is complete. The MinIO baseline is pinned to the
true last open-source release, built from source because no official artifact
remains, and published in a registry we control. The single-node lab passes
every functional check: healthy from a clean machine, data kept across restart
and down/up, HTTPS with mc, and a rebuild from a fresh clone in under 30
seconds. The repository, board, issues and secret scanning are live. Still open:
the mentor's confirmation that the repository has no internal information, the
mentor's review of the test matrix and agreement on the commit workflow, and
the answer on running below Profile B.

## Reproduce and clean up

```bash
scripts/lab-check.sh B
docker pull ghcr.io/ooseni/minio:RELEASE.2025-10-15T17-29-55Z   # or scripts/build-minio-image.sh
cp compose/minio-single/.env.example compose/minio-single/.env   # replace both CHANGE_ME values
scripts/up.sh minio-single
scripts/mc.sh minio-single admin info lab
scripts/tls-gen.sh minio-single && scripts/down.sh minio-single && TLS=1 scripts/up.sh minio-single
TLS=1 scripts/mc.sh minio-single admin info lab

scripts/down.sh minio-single            # stop, keep data
scripts/reset.sh minio-single           # DESTRUCTIVE: delete containers, volumes and lab-data/minio-single
rm -rf certs/                           # remove the lab CA and keys
docker network rm migration-net
```
