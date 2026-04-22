# GloryRole

## Description

GloryRole is an unsupervised role mining engine written entirely in PowerShell. Instead of guessing at what cloud roles should look like, it derives them from evidence -- specifically, from what your identities *actually do* in your cloud environment. Feed it activity logs and it produces production-ready custom role definitions with only the permissions your people and service accounts truly need.

GloryRole supports both **Azure RBAC** (from Azure Activity Log or Log Analytics) and **Entra ID custom roles** (from Microsoft Graph directory audit logs or Log Analytics), enabling least-privilege role mining across your entire Microsoft cloud estate.

## The Problem

Most cloud environments suffer from permission sprawl. Roles are hand-crafted based on job titles, copied from templates, or assigned as broad built-in roles because "it's easier." Over time, identities accumulate far more permissions than they actually use. Security teams know they should enforce least privilege, but they face a fundamental question: *what roles should we actually create?*

## How It Works

GloryRole implements a complete end-to-end pipeline in ten stages:

1. **Ingest** -- Supports four modes: Azure Log Analytics (KQL summarization for Azure RBAC or Entra ID audit logs), `Get-AzActivityLog` (adaptive time-slicing), Entra ID directory audit logs (Microsoft Graph API), and local CSV. The adapter-based design means adding support for additional platforms (AWS CloudTrail, GCP Audit Logs, Active Directory security logs) requires only a new ingestion adapter.
2. **Canonicalize and Deduplicate** -- Normalizes events into standard form. Resolves identities using a priority chain (ObjectId, AppId, Caller). Eliminates retry noise via composite-key deduplication.
3. **Aggregate into Sparse Triples** -- Collapses cleaned events into `PrincipalKey|Action|Count` triples, the universal data contract for all downstream stages.
4. **Quality Gate** -- Reports dataset health: distinct principals, actions, non-zero entries, and matrix density.
5. **Prune Rare Actions** -- Removes infrequent actions using dual configurable thresholds. Retains both surviving and dropped triples for audit.
6. **Handle Read Dominance** -- Three modes (Keep, DownWeight, Exclude) to prevent read operations from overwhelming the clustering signal.
7. **Vectorize** -- Converts sparse triples into fixed-length numeric vectors using a stable, sorted feature index.
8. **Normalize** -- Log1P transformation compresses dynamic range; L2 normalization scales vectors to unit length so clustering measures behavioral profile rather than activity volume.
9. **Auto-K Clustering** -- Runs K-Means for every candidate K. Evaluates using five metrics (WCSS, WCSS second derivative, silhouette, Davies-Bouldin, Calinski-Harabasz). Weighted composite scoring selects the optimal K. Deterministic seeding (default: 42) and farthest-point empty cluster rescue ensure reproducible results.
10. **Generate and Export** -- Each cluster becomes a candidate role with a valid Azure custom role definition JSON file (for Azure RBAC modes) or Entra ID custom role definition JSON file (for Entra ID mode).

## Design Philosophy

- **Evidence over opinion.** Roles are derived from observed behavior, not from job titles or guesswork.
- **Auditability.** Every pipeline run produces a complete paper trail for governance reviews.
- **Cross-version compatibility.** Runs on Windows PowerShell 5.1 and PowerShell 7.4+ across Windows, macOS, and Linux.
- **Extensibility.** The adapter-based ingestion layer is platform-agnostic. Adding new cloud platforms requires only a new ingestion function that emits sparse triples.
- **Comprehensively tested.** Every function has a corresponding Pester 5.x test file.

## Quick Start

`Invoke-RoleMiningPipeline.ps1` has two key parameters that describe independent concerns:

- `-InputMode` selects the **data source** (where the principal-action counts come from): `CSV`, `ActivityLog`, `LogAnalytics`, or `EntraId`.
- `-RoleSchema` selects the **role-definition schema** to emit: `AzureRbac` or `EntraId`; it is **required** for schema-neutral sources and **defaulted** for schema-constrained sources.

`-RoleSchema` is **required** when the source is schema-neutral (`CSV`, `LogAnalytics`) and **defaulted** when the source is schema-constrained (`ActivityLog` → `AzureRbac`; `EntraId` → `EntraId`). Incompatible combinations (e.g., `-InputMode EntraId -RoleSchema AzureRbac`) fail fast with a clear error.

```powershell
# From a local CSV sample — Azure RBAC output
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode CSV `
    -CsvPath .\samples\principal_action_counts.csv `
    -RoleSchema AzureRbac `
    -OutputPath .\output

# From a local Entra ID CSV sample — Entra custom role output
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode CSV `
    -CsvPath .\samples\entra_id_principal_action_counts.csv `
    -RoleSchema EntraId `
    -OutputPath .\output\entra-demo

# From Azure Activity Log (requires Az module)
# RoleSchema defaults to AzureRbac for this source; can be omitted.
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode ActivityLog `
    -SubscriptionIds @('your-sub-id') `
    -Start (Get-Date).AddDays(-90) -End (Get-Date) `
    -OutputPath .\output

# From Log Analytics -- Azure RBAC (requires Az.OperationalInsights)
# A Log Analytics workspace can hold either Azure Activity or Entra
# audit tables, so RoleSchema is required.
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode LogAnalytics `
    -WorkspaceId 'your-workspace-id' `
    -RoleSchema AzureRbac `
    -Start (Get-Date).AddDays(-90) -End (Get-Date) `
    -OutputPath .\output

# From Log Analytics -- Entra ID (requires Az.OperationalInsights)
# Queries the AuditLogs table for Entra ID directory audit events,
# maps activities to microsoft.directory/* actions, and generates
# Entra ID custom role definitions.
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode LogAnalytics `
    -WorkspaceId 'your-workspace-id' `
    -RoleSchema EntraId `
    -Start (Get-Date).AddDays(-90) -End (Get-Date) `
    -OutputPath .\output\entra-la

# From Entra ID audit logs (requires Microsoft.Graph.Reports)
# RoleSchema defaults to EntraId for this source; can be omitted.
Connect-MgGraph -Scopes 'AuditLog.Read.All'
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode EntraId `
    -Start (Get-Date).AddDays(-90) -End (Get-Date) `
    -OutputPath .\output\entra

# Entra ID with category filter
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode EntraId `
    -Start (Get-Date).AddDays(-90) -End (Get-Date) `
    -EntraIdFilterCategory @('GroupManagement', 'UserManagement') `
    -OutputPath .\output\entra
```

### Migration note — breaking change in 2.0

Prior versions silently routed all non-`EntraId` modes to Azure RBAC output. Starting in `Invoke-RoleMiningPipeline.ps1` **2.0**, `-RoleSchema` must be supplied explicitly for schema-neutral sources (`CSV`, `LogAnalytics`), and `[CmdletBinding(PositionalBinding = $false)]` disables positional parameters on this entry point — all parameters must be specified by name. The previous behavior treated Azure RBAC as the implicit default, which made no principled sense for CSV/LogAnalytics inputs that could equally hold Entra, and which also would not extend cleanly as AWS IAM, GCP IAM, and Active Directory schemas are added. Existing `CSV` or `LogAnalytics` invocations must be updated to pass `-RoleSchema AzureRbac` (for the previous behavior) or `-RoleSchema EntraId` (for Entra custom roles). `ActivityLog` and `EntraId` invocations are unaffected by the `-RoleSchema` change.

### Entra ID Log Analytics ingestion (`-InputMode LogAnalytics -RoleSchema EntraId`)

When the Entra ID directory audit logs are ingested from a Log Analytics workspace, the KQL query issued by `Get-EntraIdAuditEventFromLogAnalytics` collapses retry duplicates **server-side** using `arg_min(TimeGenerated, ...)` over the composite key `(PrincipalKey, OperationName, CorrelationId)`, so that only the earliest row per composite key is returned to the client. Rows whose `CorrelationId` is missing (null, empty, or whitespace-only, matching the `REQ-DED-001` contract) are preserved unchanged via a `union` branch and are not collapsed.

Everything downstream of ingestion is unchanged:

- Activity display names are still mapped to `microsoft.directory/*` resource actions on the PowerShell side via `ConvertTo-EntraIdResourceAction`, preserving the camelCase segments that Microsoft Graph requires.
- The `CanonicalEntraIdEvent` contract (DC-6) emitted by the ingestion adapter is unchanged.
- `Remove-DuplicateCanonicalEvent` continues to act as the authoritative dedup gate after ingestion, so cross-adapter equivalence is preserved.
- Activities that the mapping table does not resolve are still recorded in `entra_unmapped_activities.csv`, whose schema is codified by a Pester contract test at `tests/PowerShell/Export-UnmappedActivityReport.Contract.Tests.ps1`.

The server-side retry-collapse lowers wire volume and client-side memory pressure at production fixture sizes without changing any emitted output. See `REQ-ING-005` in `docs/spec/requirements.md` for the full contract and equivalence gate.

#### Query partitioning (Option B)

To protect against the documented Log Analytics Query API limits (500 000 rows, ~100 MB raw / 64 MB compressed, 10-minute timeout), the `[Start, End]` range is partitioned into consecutive time-window chunks and each chunk is issued as a separate KQL query whose results are concatenated client-side. Partitioning composes cleanly with the server-side retry collapse: each chunk runs the full `arg_min` collapse independently, and retry duplicates cannot straddle chunk boundaries because they share a `CorrelationId` by definition. Chunks use a half-open upper bound (`<`) except for the terminal chunk, which uses a closed upper bound (`<=`), so no row is dropped at `End` and no row is double-counted at an internal chunk boundary. When a chunk's row count meets or exceeds `-EntraIdMaxRecordHint`, the chunk is adaptively subdivided at its integer-minute midpoint while its width is at least twice `-EntraIdMinSliceMinutes`; subdivision stops once the chunk's width is below twice `-EntraIdMinSliceMinutes` so that no resulting half drops below the floor.

Three parameters are surfaced on both `Get-EntraIdAuditEventFromLogAnalytics` and `Invoke-RoleMiningPipeline.ps1`:

| Parameter | Default | Validation | Purpose |
| --- | --- | --- | --- |
| `-EntraIdInitialSliceHours` | `24` | `1..168` | Initial chunk width in hours. The `[Start, End]` range is split into consecutive chunks of this width; the final chunk is truncated to `End`. |
| `-EntraIdMinSliceMinutes` | `15` | `1..1440` | Subdivision floor. Adaptive subdivision stops when a chunk's width is below twice this value (i.e., when splitting further would yield a half below the floor), to guarantee progress on pathologically dense time windows. |
| `-EntraIdMaxRecordHint` | `450000` | `1000..500000` | Row-count ceiling that triggers adaptive subdivision. Defaults to ~90 % of the LA Query API 500 000-row cap, leaving headroom so a chunk approaching the limit is subdivided before the API can truncate the result. |

The triad is intentionally named distinctly from the Az path's `-InitialSliceHours` / `-MinSliceMinutes` / `-MaxRecordHint` triad because the two underlying APIs have fundamentally different quantitative limits (LA Query API's 500 000-row ceiling is two orders of magnitude higher than `Get-AzActivityLog`'s 5 000 default), so a shared parameter name with radically different sensible defaults would be a footgun.

## Output Artifacts

| File | Description |
| --- | --- |
| `principal_action_counts.csv` | Post-prune, post-read-handling sparse triples |
| `features.txt` | Ordered feature (action) index |
| `quality.json` | Dataset quality metrics (principals, actions, density) |
| `autoK_candidates.csv` | Every evaluated K with all metrics, ranks, and composite score |
| `clusters.json` | Cluster-to-action mapping with principal lists |
| `role_cluster_<id>.json` | One Azure custom role definition per cluster (when `-RoleSchema AzureRbac`) |
| `entra_role_cluster_<id>.json` | One Entra ID custom role definition per cluster (when `-RoleSchema EntraId`) |
| `entra_unmapped_activities.csv` | Diagnostic list of Entra ID activities that did not map to a `microsoft.directory/*` action, emitted when the Entra ID ingestion path encounters at least one unmapped activity. Schema is codified by `tests/PowerShell/Export-UnmappedActivityReport.Contract.Tests.ps1`. |

## Who It's For

- **Security engineers** implementing or tightening RBAC who need data-driven evidence for role definitions
- **Cloud administrators** managing Azure environments with permission sprawl who want to right-size roles
- **IAM teams** building governance programs who need audit artifacts to justify role changes
- **PowerShell practitioners** interested in applied machine learning -- a real-world K-Means clustering pipeline built in pure PowerShell with no external ML dependencies

## Documentation

- [Specification](docs/spec/requirements.md) — Requirements, data contracts, and design

## Testing

Run the Pester test suite:

```powershell
Invoke-Pester -Path ./tests/PowerShell -Output Detailed
```

## Build

Generate the bundled module artifact:

```powershell
./build/Build-Module.ps1
```

This produces:

- `out/GloryRole/GloryRole.psm1`
- `out/GloryRole/GloryRole.psd1`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

MIT License - See [LICENSE](LICENSE) for details.
