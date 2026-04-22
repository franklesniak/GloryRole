# GloryRole Specification

- **Status:** Active
- **Owner:** Frank Lesniak, Danny Stutz
- **Last Updated:** 2026-04-15
- **Scope:** Defines the requirements, data contracts, and design for GloryRole, a PowerShell-based pipeline that derives least-privilege Azure RBAC and Entra ID custom role definitions from cloud activity logs using K-Means clustering.
- **Related:** [README](../../README.md)

## Purpose

GloryRole ingests Azure cloud activity logs and Entra ID directory audit logs,
builds a user-action matrix, applies unsupervised K-Means clustering with an
automatic K selection algorithm, and emits production-ready Azure custom role
definition JSON files and Entra ID custom role definition JSON files.
The tool supports Windows PowerShell 5.1 and PowerShell 7+.

## Design Goals

- **DG-1 — RBAC fidelity:** Actions MUST be derived from `Authorization.Action`
  so they can be placed directly into Azure role definition `Actions` arrays.
  Entra ID actions MUST be derived from directory audit activity display names
  and mapped to `microsoft.directory/*` resource action strings for
  `unifiedRoleDefinition` `allowedResourceActions` arrays.
- **DG-2 — Identity stability:** Principals MUST be keyed by ObjectId (humans)
  or AppId (service principals) where possible, falling back to Caller. For
  Entra ID mode, principals MUST be keyed by `InitiatedBy.User.Id` (humans)
  or `InitiatedBy.App.AppId` (service principals), falling back to
  `InitiatedBy.App.DisplayName`.
- **DG-3 — Clustering readiness:** Output vectors MUST be fixed-length
  `double[]` arrays with a stable, sorted feature index.
- **DG-4 — Cross-version support:** Core code MUST run on Windows PowerShell
  5.1 and PowerShell 7+. PS7-only operators (`??`, ternary `?:`) and PS6+
  `Group-Object -AsHashTable` MUST NOT be used.
- **DG-5 — Operational realism:** The tool MUST support four ingestion modes:
  Log Analytics / KQL summarize, `Get-AzActivityLog` with adaptive time
  slicing, Entra ID directory audit logs via Microsoft Graph API, and local
  sanitized CSV for deterministic demos.
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

### DC-6: Canonical Entra ID Event

Used when ingesting Entra ID directory audit logs via Microsoft Graph API. A
`PSCustomObject` with:

| Property | Type | Description |
| --- | --- | --- |
| `TimeGenerated` | `[datetime]` | Timestamp of the event |
| `PrincipalKey` | `[string]` | User.Id > App.AppId > App.DisplayName |
| `PrincipalType` | `[string]` | `User` or `ServicePrincipal` |
| `Action` | `[string]` | Mapped `microsoft.directory/*` resource action |
| `Result` | `[string]` | Filtered to `success` |
| `Category` | `[string]` | Audit log category (e.g., `GroupManagement`) |
| `ActivityDisplayName` | `[string]` | Original activity display name |
| `CorrelationId` | `[string]` | Used for deduplication |
| `RecordId` | `[string]` | Unique record identifier |
| `PrincipalUPN` | `[string]` | UPN from InitiatedBy (metadata) |
| `AppId` | `[string]` | Application ID from InitiatedBy (metadata) |

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

- **REQ-ING-004:** The system MUST support ingesting Entra ID directory audit
  logs via Microsoft Graph API (`Get-MgAuditLogDirectoryAudit`), mapping
  activity display names to `microsoft.directory/*` resource action strings,
  and producing DC-2 sparse triples.
  - **Rationale:** Enables least-privilege Entra ID custom role mining from
    admin activity patterns in Microsoft 365 / Entra ID tenants.
  - **Verification:** Unit test with mock Graph API output.

- **REQ-ING-005:** The system MUST support ingesting Entra ID directory audit
  logs from a Log Analytics workspace (`AuditLogs` table) via KQL, mapping
  activity display names to `microsoft.directory/*` resource action strings
  while preserving camelCase segments, and producing DC-6 canonical events
  that flow through the standard deduplication and aggregation pipeline.
  The KQL query MUST collapse retry duplicates server-side on the composite
  key `(PrincipalKey, OperationName, CorrelationId)` using
  `arg_min(TimeGenerated, ...)` so that the earliest row per key is kept,
  and MUST preserve rows whose `CorrelationId` is missing, where "missing"
  is defined consistently with REQ-DED-001 as `null`, empty, or
  whitespace-only, via a union branch. The `[Start, End]` range MUST be
  partitioned into consecutive time-window chunks and each chunk MUST be
  issued as a separate KQL query whose results are concatenated
  client-side; chunks MUST use a half-open upper bound (`<`) except for
  the terminal chunk, which uses a closed upper bound (`<=`), so no row
  is dropped at `End` and no row is double-counted at an internal
  chunk boundary. When a chunk's row count is at or above
  `-EntraIdMaxRecordHint`, the chunk MUST be adaptively subdivided in
  half down to a floor of `-EntraIdMinSliceMinutes`.
  - **Rationale:** Enables Entra ID role mining from workspaces that receive
    directory audit logs via diagnostic settings, without requiring a direct
    Microsoft Graph connection. Server-side retry collapse reduces the
    number of rows transferred over the wire and processed client-side,
    which materially lowers cost and memory pressure at production fixture
    sizes while preserving the contract that `Remove-DuplicateCanonicalEvent`
    would otherwise enforce client-side. Query partitioning (Option B)
    protects the ingestion path against the documented Log Analytics Query
    API limits (500 000 rows, ~100 MB raw / 64 MB compressed, 10-minute
    timeout) and composes cleanly with the Option A server-side collapse:
    each chunk's KQL runs the full `arg_min` collapse independently, and
    retry duplicates cannot straddle chunk boundaries because they share
    a `CorrelationId` (and therefore a single logical `TimeGenerated`
    neighborhood) by definition.
  - **Partitioning parameters.** The Entra LA ingestion path exposes a
    triad of slice-tuning parameters on
    `Get-EntraIdAuditEventFromLogAnalytics.ps1` and surfaces all three on
    `Invoke-RoleMiningPipeline.ps1` for `-InputMode LogAnalytics
    -RoleSchema EntraId`:

    | Parameter | Default | Validation |
    |---|---|---|
    | `-EntraIdInitialSliceHours` | `24` | `[ValidateRange(1, 168)]` |
    | `-EntraIdMinSliceMinutes` | `15` | `[ValidateRange(1, 1440)]` |
    | `-EntraIdMaxRecordHint` | `450000` | `[ValidateRange(1000, 500000)]` |

    The triad is intentionally named distinctly from the Az path's
    `-InitialSliceHours` / `-MinSliceMinutes` / `-MaxRecordHint` triad
    because the two underlying APIs have fundamentally different
    quantitative limits. `Get-AzActivityLog`'s `MaxRecordHint` default
    is `5000`; the LA Query API hard ceiling is `500000` — two orders
    of magnitude apart. A shared parameter name with radically different
    sensible defaults would be a footgun. The `EntraId*` prefix matches
    the existing pipeline convention (`-EntraIdFilterCategory`,
    `-EntraIdRoleNamePrefix`) and signals that the chunking invariants
    are Entra-path-specific (null-`CorrelationId` union bypass, activity
    mapping) and may not transfer verbatim to other LA-backed paths.
    The `450000` default is approximately 90 % of the API cap, leaving
    margin for rows that arrive between the count probe and the actual
    query.
  - **Verification:** Unit test with mock `Invoke-AzOperationalInsightsQuery`
    output; row-count gate in the equivalence suite asserts
    `emitted <= floor((1 - DuplicateRatio + 0.10) * baseline)` for the
    locked synthetic fixture parameters (`Count=10000`, `Seed=42`,
    `DuplicateRatio in {0.0, 0.25, 0.5}`). Chunked-wrapping equivalence
    between coarse (168 h) and fine (1 h) chunk widths is verified by
    `Test-StageOneEquivalence`. Chunk-boundary correctness (no drop, no
    double-count across an internal seam) and adaptive-subdivision
    convergence (a chunk that hits `-EntraIdMaxRecordHint` subdivides
    down toward `-EntraIdMinSliceMinutes` and still produces identical
    stage-one outputs) are each covered by dedicated Pester cases in
    `tests/PowerShell/Get-EntraIdAuditEventFromLogAnalytics.Equivalence.Tests.ps1`.
    The `entra_unmapped_activities.csv` diagnostic artifact emitted when the
    Entra ID ingestion path (both `-InputMode EntraId` and
    `-InputMode LogAnalytics -RoleSchema EntraId`) encounters one or
    more activity display names absent from the
    `ConvertTo-EntraIdResourceAction` mapping table is defined by the
    contract test at
    `tests/PowerShell/Export-UnmappedActivityReport.Contract.Tests.ps1`,
    which is the authoritative definition of the artifact's header,
    column order, and per-row invariants.
  - **Option C deferral:** Server-side activity-to-action mapping
    (embedding the `ConvertTo-EntraIdResourceAction` mapping table
    inside the KQL query as a `datatable` literal) was evaluated and
    deferred. Rationale: the retry-collapse in REQ-ING-005's current
    implementation eliminates the dominant wire-volume cost for
    directory audit logs; embedding the mapping table in KQL would
    require a code-generation toolchain to prevent drift between the
    PowerShell mapping and the KQL copy, plus a secondary reverse-join
    query to reconstruct the unmapped-activity diagnostic artifact.
    This work becomes in-scope only when production-tenant telemetry
    shows (a) stage-1 wall-clock > 30 seconds for a 30-day ingestion
    window after retry-collapse and query partitioning are both in
    place, AND (b) the ratio of KQL-returned rows to distinct
    (PrincipalKey, Action) pairs exceeds 5.0.

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
  `CorrelationId` MUST be kept. When the canonical event shape does
  not carry a `ResourceId` (e.g., DC-6 Canonical Entra ID Event), the
  missing value MUST be treated as an empty string in the composite
  dedupe key so that the rule applies uniformly across event shapes.
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

- **REQ-ROL-002:** When `RoleSchema` resolves to `AzureRbac`, the system MUST
  emit valid Azure custom role definition JSON with `Name`, `IsCustom`,
  `Description`, `Actions`, `NotActions`, `DataActions`, `NotDataActions`,
  and `AssignableScopes`.
  - **Verification:** Unit test.

- **REQ-ROL-003:** When `RoleSchema` resolves to `EntraId`, the system MUST
  emit valid Entra ID custom role definition JSON in the
  `unifiedRoleDefinition` format with `displayName`, `description`,
  `isEnabled`, and `rolePermissions` containing `allowedResourceActions`
  in the `microsoft.directory/*` namespace.
  - **Verification:** Unit test.

- **REQ-ROL-004:** `InputMode` (data source) and `RoleSchema` (output role
  schema) are independent concerns. `RoleSchema` defaults where the source
  is schema-constrained (`ActivityLog` → `AzureRbac`; `EntraId` → `EntraId`)
  and is required for schema-neutral sources (`CSV`, `LogAnalytics`). The
  tool MUST NOT assume a default platform for schema-neutral inputs.
  Incompatible combinations (e.g., `InputMode EntraId` with
  `RoleSchema AzureRbac`) MUST fail fast with an actionable error.
  - **Verification:** Unit test.

### Export

- **REQ-EXP-001:** The system MUST export the following artifacts per run:
  `principal_action_counts.csv`, `features.txt`, `quality.json`,
  `autoK_candidates.csv`, `clusters.json`, and one
  `role_cluster_<id>.json` (Azure RBAC) or `entra_role_cluster_<id>.json`
  (Entra ID) per cluster.
  - **Verification:** Integration test.

- **REQ-EXP-002:** When the Entra ID ingestion path encounters audit records
  whose `ActivityDisplayName` does not map to a `microsoft.directory/*`
  resource action, the system MUST:
  (a) export an `entra_unmapped_activities.csv` artifact listing each
  unmapped `ActivityDisplayName`, its `Category`, occurrence `Count`, and a
  sample `CorrelationId` / `RecordId` for troubleshooting;
  (b) include `EntraUnmappedActivityCount` and
  `EntraUnmappedDistinctActivities` in the `quality.json` artifact;
  (c) emit a `Write-Warning` when the unmapped-activity percentage exceeds a
  configurable threshold (default 15%, adjustable via
  `-UnmappedActivityWarningThreshold`). A non-zero unmapped count is
  expected because the mapping table intentionally excludes self-service and
  informational activities. The threshold distinguishes expected
  non-administrative skips from potential coverage gaps.
  - **Rationale:** Turns silent mapping incompleteness into visible,
    actionable diagnostics and creates a feedback loop for expanding the
    mapping table over time.
  - **Verification:** Unit test with mock ingestion output verifying artifact
    presence, quality.json fields, and threshold-triggered warnings.

### Compatibility

- **REQ-COM-001:** Scripts MUST NOT use PS7-only operators (`??`, ternary
  `?:`), `Group-Object -AsHashTable`, or other constructs unavailable in
  Windows PowerShell 5.1.
  - **Verification:** Manual review and CI testing on both PS 5.1 and PS 7.

## Pipeline Stages

The orchestration entry point MUST execute the following stages in order:

1. Ingest counts via Log Analytics, Activity Log, Entra ID audit logs, or CSV
   sample
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
