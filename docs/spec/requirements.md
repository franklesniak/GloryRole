# GloryRole Specification

- **Status:** Active
- **Owner:** Frank Lesniak, Danny Stutz
- **Last Updated:** 2026-03-19
- **Scope:** Defines the requirements, data contracts, and design for GloryRole, a PowerShell-based pipeline that derives least-privilege Azure RBAC role definitions from cloud activity logs using K-Means clustering.
- **Related:** [README](../../README.md)

## Purpose

GloryRole ingests Azure cloud activity logs, builds a user-action
matrix, applies unsupervised K-Means clustering with an automatic K selection
algorithm, and emits production-ready Azure custom role definition JSON files.
The tool supports Windows PowerShell 5.1 and PowerShell 7+.

## Design Goals

- **DG-1 — RBAC fidelity:** Actions MUST be derived from `Authorization.Action`
  so they can be placed directly into Azure role definition `Actions` arrays.
- **DG-2 — Identity stability:** Principals MUST be keyed by ObjectId (humans)
  or AppId (service principals) where possible, falling back to Caller.
- **DG-3 — Clustering readiness:** Output vectors MUST be fixed-length
  `double[]` arrays with a stable, sorted feature index.
- **DG-4 — Cross-version support:** Core code MUST run on Windows PowerShell
  5.1 and PowerShell 7+. PS7-only operators (`??`, ternary `?:`) and PS6+
  `Group-Object -AsHashTable` MUST NOT be used.
- **DG-5 — Operational realism:** The tool MUST support three ingestion modes:
  Log Analytics / KQL summarize, `Get-AzActivityLog` with adaptive time
  slicing, and local sanitized CSV for deterministic demos.
- **DG-6 — Human review:** The tool MUST emit artifacts (counts, dropped
  actions, quality metrics, cluster-to-action sets, role JSON) that make review
  and governance feasible.

## Data Contracts

### DC-1: Canonical Admin Event

Used when ingesting raw Activity Log records. A `PSCustomObject` with:

| Property | Type | Description |
| --- | --- | --- |
| `TimeGenerated` | `[datetime]` | Timestamp of the event |
| `SubscriptionId` | `[string]` | Azure subscription ID |
| `PrincipalKey` | `[string]` | ObjectId > AppId > Caller |
| `PrincipalType` | `[string]` | `User`, `ServicePrincipal`, or `Unknown` |
| `Action` | `[string]` | Lowercase `Authorization.Action` value |
| `Status` | `[string]` | Filtered to `Succeeded` |
| `ResourceId` | `[string]` | Azure resource ID (metadata) |
| `CorrelationId` | `[string]` | Used for retry deduplication |
| `Caller` | `[string]` | Original caller value |
| `PrincipalUPN` | `[string]` | UPN from claims (metadata) |
| `AppId` | `[string]` | Application ID from claims (metadata) |

### DC-2: Principal-Action Count (Sparse Triple)

The preferred intermediate format. Everything after ingestion MUST operate on
this contract.

| Property | Type | Description |
| --- | --- | --- |
| `PrincipalKey` | `[string]` | Identity key |
| `Action` | `[string]` | Normalized action string |
| `Count` | `[double]` | Occurrence count |

### DC-3: Vector Row

Dense vector representation for clustering input.

| Property | Type | Description |
| --- | --- | --- |
| `PrincipalKey` | `[string]` | Identity key |
| `Vector` | `[double[]]` | Fixed-length feature vector |
| `TotalActions` | `[double]` | Sum of counts (metadata) |

### DC-4: K-Means Result

| Property | Type | Description |
| --- | --- | --- |
| `K` | `[int]` | Number of clusters |
| `Assignments` | `[hashtable]` | PrincipalKey → cluster ID mapping |
| `Centroids` | `[List[double[]]]` | Centroid vectors |
| `SSE` | `[double]` | Sum of squared errors |

### DC-5: Auto-K Result

| Property | Type | Description |
| --- | --- | --- |
| `RecommendedK` | `[int]` | Selected K value |
| `BestModel` | K-Means Result | The model for the recommended K |
| `Candidates` | `[array]` | All evaluated K values with SSE, silhouette, Davies-Bouldin, Calinski-Harabasz, WCSS 2nd derivative, per-metric ranks, and composite rank |

## Requirements

### Ingestion

- **REQ-ING-001:** The system MUST support ingesting pre-aggregated sparse
  triples from Log Analytics via KQL.
  - **Rationale:** Scalable production path with server-side summarization.
  - **Verification:** Integration test with mock query results.

- **REQ-ING-002:** The system MUST support ingesting raw events via
  `Get-AzActivityLog` with adaptive time slicing when a segment returns near
  the record ceiling.
  - **Rationale:** Enables usage without a Log Analytics workspace.
  - **Verification:** Unit test with mock `Get-AzActivityLog` output.

- **REQ-ING-003:** The system MUST support ingesting sparse triples from a
  local CSV file.
  - **Rationale:** Deterministic demo and CI testing support.
  - **Verification:** Unit test with sample CSV.

### Canonicalization

- **REQ-CAN-001:** Actions MUST be normalized to lowercase with whitespace
  trimmed.
  - **Verification:** Unit test.

- **REQ-CAN-002:** Principal keys MUST follow the precedence: ObjectId > AppId
  > Caller. Records with no resolvable principal MUST be dropped.
  - **Verification:** Unit test.

### Deduplication and Aggregation

- **REQ-DED-001:** Retry deduplication MUST use the composite key
  `PrincipalKey|Action|ResourceId|CorrelationId`. Records without a
  `CorrelationId` MUST be kept.
  - **Verification:** Unit test.

- **REQ-AGG-001:** Canonical events MUST be aggregated into
  `PrincipalActionCount` sparse triples by summing occurrences per
  principal-action pair.
  - **Verification:** Unit test.

### Quality Gates

- **REQ-QG-001:** The system MUST compute and report: distinct principal count,
  distinct action count, non-zero entry count, matrix density, top 10 actions,
  and top 10 principals.
  - **Verification:** Unit test.

### Feature Pruning

- **REQ-PRU-001:** Actions MUST be prunable by dual thresholds: minimum
  distinct principals and minimum total count. Pruned actions and their stats
  MUST be reported.
  - **Verification:** Unit test.

### Read-Dominance Handling

- **REQ-RDH-001:** The system MUST support three read-handling modes: `Keep`,
  `DownWeight` (default, weight = 0.25), and `Exclude`. Actions ending in
  `/read` are considered read actions.
  - **Verification:** Unit test.

### Vectorization

- **REQ-VEC-001:** The feature index MUST be built from sorted unique action
  names to ensure stable, reproducible vector dimensions.
  - **Verification:** Unit test.

- **REQ-VEC-002:** Vector normalization MUST support Log1P and L2
  transformations, both enabled by default.
  - **Verification:** Unit test.

### Clustering

- **REQ-CLU-001:** K-Means MUST use deterministic seeding (default seed = 42)
  and reseed empty clusters using the farthest-point heuristic.
  - **Verification:** Unit test.

- **REQ-CLU-002:** Auto-K MUST evaluate K values from MinK (default 2) to MaxK
  (default 12), computing WCSS, WCSS second derivative (central differences),
  approximate silhouette score, Davies-Bouldin index, and Calinski-Harabasz
  index for each candidate. Each metric MUST be converted to an ordinal rank
  (1 = best) and combined via a weighted average. Default weights: WCSS
  second derivative (40), silhouette (18), cluster count bias (14, conditional),
  Davies-Bouldin (13), Calinski-Harabasz (12), raw WCSS (3). The K with the
  lowest composite rank wins. When the maximum silhouette score across all
  candidates is below 0.4, a cluster-count rank biased toward
  Ceiling(Sqrt(N)) MUST be included. This methodology is aligned with
  AutoCategorizerPS.
  - **Verification:** Unit test.

### Role Generation

- **REQ-ROL-001:** Each cluster MUST produce a set of unique actions derived
  from the original (pre-vectorization) sparse triples.
  - **Verification:** Unit test.

- **REQ-ROL-002:** The system MUST emit valid Azure custom role definition JSON
  with `Name`, `IsCustom`, `Description`, `Actions`, `NotActions`,
  `DataActions`, `NotDataActions`, and `AssignableScopes`.
  - **Verification:** Unit test.

### Export

- **REQ-EXP-001:** The system MUST export the following artifacts per run:
  `principal_action_counts.csv`, `features.txt`, `quality.json`,
  `autoK_candidates.csv`, `clusters.json`, and one
  `role_cluster_<id>.json` per cluster.
  - **Verification:** Integration test.

### Compatibility

- **REQ-COM-001:** Scripts MUST NOT use PS7-only operators (`??`, ternary
  `?:`), `Group-Object -AsHashTable`, or other constructs unavailable in
  Windows PowerShell 5.1.
  - **Verification:** Manual review and CI testing on both PS 5.1 and PS 7.

## Pipeline Stages

The orchestration entry point MUST execute the following stages in order:

1. Ingest counts via Log Analytics, Activity Log, or CSV sample
2. Quality report with warnings
3. Prune actions and keep dropped report
4. Apply read-dominance handling mode
5. Optional TF-IDF weighting
6. Build feature index and vector rows
7. Normalize vectors (Log1P + L2 default)
8. Auto-K loop to select optimal K
9. Generate cluster action sets
10. Emit role JSON per cluster
11. Export all artifacts

## Open Questions

- **OQ-1:** Whether to include the optional AI naming assist in the initial
  release. Owner: Frank Lesniak, Danny Stutz.
