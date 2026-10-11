# Test matrix

Features x topology x storage type, with the pass criterion for each row. Every
row runs on MinIO first and is repeated on Silo with the same command or SDK
call, the same Compose limits and the same data (ST12, ST13). A row passes only
when its criterion holds on the product under test; a MinIO to Silo difference
is recorded as Same / Improved / Degraded / Broken in ST12 and ST15.

Status: draft for mentor review (ST01). Owner: the intern.

## Dimensions

| Dimension | Values |
|---|---|
| Product | MinIO `RELEASE.2025-10-15T17-29-55Z`, Silo `RELEASE.2026-09-16T00-00-00Z` |
| Topology | **SN** single node, 1 drive. **D4** distributed, 4 nodes x 1 drive (Profile B; 4 x 2 under Profile A) behind a load-balancer container. **MIG** MinIO D4 source + Silo D4 target + proxy + workload, together |
| Storage | **LV** local volume: a bind-mounted directory on the SSD (ext4). **TF** tmpfs capped in size, only for the drive-full failure test. NFS was removed from the Epic on 2026-09-28 and is not tested |
| Client | `mc` (MinIO), `mcli` (Silo), aws-cli, Python boto3, one MinIO SDK |

## Core S3 and metadata (ST04, re-run in ST12)

| ID | Feature | Topology | Storage | Pass criterion |
|---|---|---|---|---|
| S3-01 | Bucket create, list, delete | SN | LV | All succeed; deleting a non-empty bucket fails with `BucketNotEmpty` |
| S3-02 | Put, get, head, delete object | SN | LV | GET returns the same SHA-256 as uploaded; HEAD size and ETag match |
| S3-03 | Copy object | SN | LV | Copy has identical content and metadata (or the replaced metadata when requested) |
| S3-04 | Multipart upload (above 64 MiB, 5 MiB parts) | SN | LV | Completed object's SHA-256 matches the source; aborted uploads leave no parts listed |
| S3-05 | Range reads | SN | LV | Bytes returned equal the same slice of the source file |
| S3-06 | Presigned GET and PUT URLs | SN | LV | Work before expiry; return 403 after expiry |
| S3-07 | ListObjects v1 and v2, prefixes, delimiters, pagination over 1,000 keys | SN | LV | Every key listed exactly once; continuation tokens complete the listing |
| S3-08 | Batch delete (DeleteObjects) | SN | LV | All requested keys removed; per-key errors reported |
| S3-09 | User metadata, object tags, bucket tags | SN | LV | Values read back exactly, including case and UTF-8 |
| S3-10 | Conditional requests: If-Match, If-None-Match, conditional DELETE | SN | LV | Matching condition succeeds; mismatch returns 412 (O04 on Silo) |
| S3-11 | Unsupported APIs (ACLs) and error codes | SN | LV | Same S3 error code on both products, or the difference is recorded |
| S3-12 | S3 conformance suite | SN | LV | Pass rate recorded on both; every new failure on Silo explained |

## Access control and encryption (ST04, ST08, ST12)

| ID | Feature | Topology | Storage | Pass criterion |
|---|---|---|---|---|
| AC-01 | IAM users, groups, policies | SN | LV | Allowed calls succeed and denied calls return AccessDenied, as the policy says |
| AC-02 | Service accounts and STS (AssumeRole) | SN | LV | Temporary credentials work until expiry, then fail; session policy limits apply |
| AC-03 | Custom Allow/Deny policies, object ARNs, source-IP conditions | SN | LV | Identical decisions on MinIO and Silo, or every difference assessed (O02) |
| AC-04 | Anonymous (public) bucket policy | SN | LV | Anonymous read works only where the policy allows it |
| AC-05 | SSE-S3 | SN | LV | Object stored encrypted (`mc stat` shows it) and reads back intact |
| AC-06 | SSE-C | SN | LV | Read needs the same customer key; the wrong key fails |
| AC-07 | SSE-KMS | SN | LV | Works if a KMS container is available; otherwise "Not available" with the reason |
| AC-08 | TLS with the lab CA | SN | LV | `mc` over HTTPS verifies the certificate; plain HTTP is refused when TLS is on |

## Versioning, object lock, lifecycle (ST04, ST12)

| ID | Feature | Topology | Storage | Pass criterion |
|---|---|---|---|---|
| VL-01 | Versioning enable, suspend, re-enable | SN | LV | State transitions match S3 semantics; versions kept across suspend |
| VL-02 | Delete markers, permanent version delete, restore | SN | LV | Delete marker hides the object; deleting the marker restores it |
| VL-03 | ListObjectVersions at scale (over 10,000 versions) | SN | LV | Every version listed once; time recorded |
| VL-04 | Object lock: governance and compliance retention | SN | LV | Locked versions cannot be deleted; governance bypass works only with the permission |
| VL-05 | Legal hold, retention extension, default bucket retention | SN | LV | Hold blocks deletion until removed; extension accepted, shortening refused in compliance mode |
| VL-06 | Lifecycle expiry: current, noncurrent, delete-marker cleanup | SN | LV | Objects expire; delay between due time and actual expiry measured |

## Notifications, quotas, observability (ST04, ST12)

| ID | Feature | Topology | Storage | Pass criterion |
|---|---|---|---|---|
| OB-01 | Bucket notifications to a webhook | SN | LV | Every put and delete event arrives once, with the right key |
| OB-02 | Bucket quota | SN | LV | Writes over the quota are refused |
| OB-03 | Prometheus metrics endpoint | SN, D4 | LV | Scrape succeeds; metric names match (`minio_*` stays on Silo) |
| OB-04 | `mc admin info`, `admin trace`, logs, console | SN | LV | All usable; differences between `mc` and `mcli` recorded |

## Distributed mode (ST05, re-run in ST12)

| ID | Feature | Topology | Storage | Pass criterion |
|---|---|---|---|---|
| DM-01 | Cluster boots from Compose | D4 | LV | All nodes online and erasure set healthy within 3 minutes, on every boot |
| DM-02 | One node down | D4 | LV | Reads and writes continue at the default parity; no data loss after it returns |
| DM-03 | Drive wiped, then healed | D4 | LV | `mc admin heal` restores it; manifest compare shows 0 missing and 0 corrupted; heal time recorded |
| DM-04 | Failures beyond parity | D4 | LV | Writes refused (or reads refused) as the erasure maths predicts; recovers when nodes return |
| DM-05 | Network partition (`docker network disconnect`) | D4 | LV | Behavior matches expectation; no split-brain writes |
| DM-06 | Rolling restart gated by health checks | D4 | LV | 0 failed client requests after retries (`silo healthcheck --maintenance cluster` gate on Silo) |
| DM-07 | Pool expansion, decommission, rebalance | D4 + pool | LV | Completes with no data loss; downtime measured (O06 on Silo) |

## Replication (ST03, ST08 to ST10, ST12)

| ID | Feature | Topology | Storage | Pass criterion |
|---|---|---|---|---|
| RP-01 | One-way bucket replication, MinIO to MinIO | 2 x SN | LV | Objects, versions, delete markers, tags and metadata match by manifest |
| RP-02 | Two-way replication and conflicts | 2 x SN | LV | Both sides converge; conflict behavior documented |
| RP-03 | Existing-object replication and batch replication | 2 x SN | LV | Backlog reaches 0; manifest compare shows 0 differences |
| RP-04 | Site replication (IAM, bucket config, data) | 2 x SN | LV | Works MinIO to MinIO; MinIO to Silo result or the reason it was not done |
| RP-05 | MinIO to Silo, feature by feature | SN to SN | LV | Plain, multipart, tagged, user metadata, versioned overwrite, delete marker, retention, legal hold, SSE-S3, SSE-C each PASS or FAIL with evidence |
| RP-06 | Replication with the target down, network cut, resync | MIG | LV | Backlog drains to 0 after recovery; 0 missing objects |
| RP-07 | Drive full on the target | MIG | TF | Replication pauses with a clear error and resumes after space is freed; 0 lost objects |
| RP-08 | Silo to Silo replication | 2 x SN | LV | Same results as RP-01 to RP-03 |

## Migration by replication (ST07 to ST10)

| ID | Feature | Topology | Storage | Pass criterion |
|---|---|---|---|---|
| MG-01 | Lab headroom: source, target, proxy, workload, monitoring together | MIG | LV | All healthy; `docker stats` recorded; continuous workload runs 30 minutes with 0 failed requests |
| MG-02 | IAM and bucket config export and import | MIG | LV | Everything transferable exists on Silo; non-transferable items listed; exports never committed |
| MG-03 | Backfill | MIG | LV | Backlog 0; time, MiB/s, objects/s recorded; 0 failed client requests |
| MG-04 | Live traffic and lag | MIG | LV | Average and p95 lag measured; convergence after load stops |
| MG-05 | Parity | MIG | LV | Manifest compare: 0 missing, 0 corrupted, 0 unexplained differences; `mc diff` and checksum verify agree |
| MG-06 | Deliberate difference repaired | MIG | LV | Injected difference detected and repaired by resync |
| MG-07 | Cutover through the proxy (reads, then writes) | MIG | LV | 0 failed requests after SDK retries; no lost or duplicate writes |
| MG-08 | Rollback with reverse replication | MIG | LV | 0 failed requests, 0 lost writes; Silo rollback limits documented (O07) |
| MG-09 | Decommission the source | MIG | LV | Silo serves alone after source shutdown and restart; manifest still matches |

## In-place swap baseline (ST11)

| ID | Feature | Topology | Storage | Pass criterion |
|---|---|---|---|---|
| IP-01 | Swap all nodes' image to Silo at once, on a copy of the volumes | D4 | LV | Downtime measured; data and IAM intact by manifest |
| IP-02 | One Silo node among MinIO nodes | D4 | LV | Node stays in `activating`; checksum-mismatch log lines captured |

## Performance (ST06, ST13)

| ID | Feature | Topology | Storage | Pass criterion |
|---|---|---|---|---|
| PF-01 | Raw disk baseline (fio) | host | LV | Sequential and random read/write MiB/s and IOPS recorded |
| PF-02 | warp: small-object PUT, GET, DELETE, LIST | SN, D4 | LV | MiB/s, ops/s, p50/p95/p99 recorded, 3 runs each, variance reported |
| PF-03 | warp: large-object PUT, GET | SN, D4 | LV | As PF-02 |
| PF-04 | warp: mixed, multipart, versioned | SN, D4 | LV | As PF-02 |
| PF-05 | Concurrency and noisy-neighbor stress | SN, D4 | LV | Effect quantified; bottleneck named (disk, CPU or software) |
| PF-06 | MinIO versus Silo under identical conditions | SN, D4 | LV | Delta % per metric with the noise level; labelled indicative only below Profile A |
