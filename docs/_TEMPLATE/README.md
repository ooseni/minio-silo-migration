# NN. Sub-task title

> Jira: DEV-NNN | Sub-task STNN | Status: in progress / done | Date: YYYY-MM-DD

Copy this folder to `docs/NN-short-name/` for each sub-task. Keep raw text
evidence in `evidence/` and images in `screenshots/`. Every PASS or FAIL below
must point to a file in `evidence/`. No secrets, internal IPs, hostnames,
domains or emails anywhere, including screenshots.

## Goal

What this sub-task proves, in two or three sentences, and the acceptance
criteria it has to meet.

## Environment

| Item | Value |
|---|---|
| MinIO image | `ghcr.io/ooseni/minio:RELEASE...` (digest `sha256:...`) |
| Silo image | `docker.io/pgsty/silo:RELEASE...` (digest `sha256:...`) |
| Client | `mc` / `mcli` version |
| Docker / Compose | Engine `x.y.z` / Compose `vX.Y.Z` |
| OS | e.g. Ubuntu 26.04 on WSL2 |
| Local machine | CPU, RAM available to Docker, free SSD, profile (A or B) |
| Topology | e.g. single node, 4 nodes x 1 drive |
| Compose limits | CPU and memory per container |
| Date | YYYY-MM-DD |

## Prerequisites

What must already be running or exist (projects, buckets, dataset, certificates).

## Step-by-step procedure

Write the expected result **before** running each step.

| # | Command | Expected result | Actual result | PASS/FAIL | Evidence |
|---|---|---|---|---|---|
| 1 | `scripts/up.sh minio-single` | container healthy within 60 s | | | `evidence/01-up.txt` |

## Results

Summary table of what was measured (times, counts, throughput, latency).

## Findings

Anything unexpected, degraded or broken, with severity, and any behavior that
differs between MinIO and Silo. Failures are documented, never worked around
silently.

## Conclusion

Did the sub-task meet its acceptance criteria? What does it mean for the
migration decision?

## Reproduce and clean up

Exact commands to rerun this sub-task from a clean machine, and to remove what
it created.
