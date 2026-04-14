# GloryRole

## Description

GloryRole is an unsupervised role mining engine written entirely in PowerShell. Instead of guessing at what cloud roles should look like, it derives them from evidence -- specifically, from what your identities *actually do* in your cloud environment. Feed it activity logs and it produces production-ready custom role definitions with only the permissions your people and service accounts truly need.

GloryRole supports both **Azure RBAC** (from Azure Activity Log or Log Analytics) and **Entra ID custom roles** (from Microsoft Graph directory audit logs), enabling least-privilege role mining across your entire Microsoft cloud estate.

## The Problem

Most cloud environments suffer from permission sprawl. Roles are hand-crafted based on job titles, copied from templates, or assigned as broad built-in roles because "it's easier." Over time, identities accumulate far more permissions than they actually use. Security teams know they should enforce least privilege, but they face a fundamental question: *what roles should we actually create?*

## How It Works

GloryRole implements a complete end-to-end pipeline in ten stages:

1. **Ingest** -- Supports four modes: Azure Log Analytics (KQL summarization), `Get-AzActivityLog` (adaptive time-slicing), Entra ID directory audit logs (Microsoft Graph API), and local CSV. The adapter-based design means adding support for additional platforms (AWS CloudTrail, GCP Audit Logs, Active Directory security logs) requires only a new ingestion adapter.
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

```powershell
# From a local CSV sample
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode CSV `
    -CsvPath .\samples\principal_action_counts.csv `
    -OutputPath .\output

# From Azure Activity Log (requires Az module)
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode ActivityLog `
    -SubscriptionIds @('your-sub-id') `
    -Start (Get-Date).AddDays(-90) -End (Get-Date) `
    -OutputPath .\output

# From Log Analytics (requires Az.OperationalInsights)
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode LogAnalytics `
    -WorkspaceId 'your-workspace-id' `
    -Start (Get-Date).AddDays(-90) -End (Get-Date) `
    -OutputPath .\output

# From Entra ID audit logs (requires Microsoft.Graph.Reports)
Connect-MgGraph -Scopes 'AuditLog.Read.All'
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode EntraId `
    -Start (Get-Date).AddDays(-90) -End (Get-Date) `
    -OutputPath .\output\entra

# Entra ID with category filter
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode EntraId `
    -Start (Get-Date).AddDays(-90) -End (Get-Date) `
    -EntraIdFilterCategory @('GroupManagement', 'UserManagement') `
    -OutputPath .\output\entra

# From Entra ID sample CSV (for demos/testing)
.\src\Invoke-RoleMiningPipeline.ps1 -InputMode CSV `
    -CsvPath .\samples\entra_id_principal_action_counts.csv `
    -OutputPath .\output\entra-demo
```

## Output Artifacts

| File | Description |
| --- | --- |
| `principal_action_counts.csv` | Post-prune, post-read-handling sparse triples |
| `features.txt` | Ordered feature (action) index |
| `quality.json` | Dataset quality metrics (principals, actions, density) |
| `autoK_candidates.csv` | Every evaluated K with all metrics, ranks, and composite score |
| `clusters.json` | Cluster-to-action mapping with principal lists |
| `role_cluster_<id>.json` | One Azure custom role definition per cluster (RBAC modes) |
| `entra_role_cluster_<id>.json` | One Entra ID custom role definition per cluster (EntraId mode) |

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
