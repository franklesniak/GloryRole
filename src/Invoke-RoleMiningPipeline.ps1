# .SYNOPSIS
# GloryRole orchestration entry point.
#
# .DESCRIPTION
# Executes the full role-mining pipeline: ingest activity data, quality
# gate, prune rare actions, handle read dominance, optionally apply
# TF-IDF, vectorize, normalize, Auto-K cluster, generate role JSON, and
# export all artifacts.
#
# .PARAMETER InputMode
# Mandatory. Selects the **data source** (where the principal-action
# counts come from). Valid values are 'CSV', 'ActivityLog',
# 'LogAnalytics', and 'EntraId'. This parameter describes the shape
# of the input only and is **independent** of which role-definition
# schema the pipeline emits at the end; see RoleSchema.
#
# .PARAMETER RoleSchema
# Selects the **role-definition schema** written to the per-cluster
# role JSON artifacts. Valid values are 'AzureRbac' (Azure RBAC
# `roleDefinition` JSON with `Actions` / `AssignableScopes`) and
# 'EntraId' (Microsoft Graph `unifiedRoleDefinition` JSON with
# `rolePermissions.allowedResourceActions` in the
# `microsoft.directory/*` namespace).
#
# For **schema-neutral** data sources, `RoleSchema` is **required**
# because the tool does not assume a default platform:
#   - InputMode 'CSV': the CSV is a neutral container; caller must
#     pass `-RoleSchema AzureRbac` or `-RoleSchema EntraId`.
#   - InputMode 'LogAnalytics': workspaces can hold Azure Activity
#     logs or Entra ID directory audit logs; caller must pass the
#     matching schema. When `AzureRbac`, the bundled adapter queries
#     the `AzureActivity` table and lowercases actions. When
#     `EntraId`, it queries the `AuditLogs` table, maps activities
#     via `ConvertTo-EntraIdResourceAction`, and preserves camelCase
#     `microsoft.directory/*` action segments.
# For **schema-constrained** data sources, `RoleSchema` defaults
# (and passing an incompatible value throws):
#   - InputMode 'ActivityLog' (Azure Activity Log cmdlet) defaults
#     to 'AzureRbac'.
#   - InputMode 'EntraId' (Microsoft Graph directory audit logs)
#     defaults to 'EntraId'.
# Artifact naming: 'AzureRbac' produces `role_cluster_<id>.json`;
# 'EntraId' produces `entra_role_cluster_<id>.json`.
#
# .PARAMETER OutputPath
# Mandatory. Directory where all artifacts are exported. Created
# automatically if it does not exist.
#
# .PARAMETER CsvPath
# Required when InputMode is 'CSV'. Path to the input CSV file
# containing principal action counts.
#
# .PARAMETER SubscriptionIds
# Required when InputMode is 'ActivityLog'. One or more Azure
# subscription IDs to query for activity log events.
#
# .PARAMETER Start
# Required when InputMode is 'ActivityLog', 'LogAnalytics', or
# 'EntraId'. Start of the time window for data collection.
#
# .PARAMETER End
# Required when InputMode is 'ActivityLog', 'LogAnalytics', or
# 'EntraId'. End of the time window for data collection.
#
# .PARAMETER InitialSliceHours
# Initial time-slice width in hours used for adaptive time-slicing when
# querying Azure Activity Log. Default is 24.
#
# .PARAMETER MinSliceMinutes
# Minimum time-slice width in minutes used for adaptive time-slicing
# when querying Azure Activity Log. Default is 15.
#
# .PARAMETER MaxRecordHint
# Target maximum number of records per time slice when querying Azure
# Activity Log. Default is 5000.
#
# .PARAMETER WorkspaceId
# Required when InputMode is 'LogAnalytics'. The Log Analytics
# workspace ID to query.
#
# .PARAMETER EntraIdFilterCategory
# Optional when InputMode is 'EntraId'. One or more audit log
# categories to filter (e.g., 'GroupManagement', 'UserManagement',
# 'RoleManagement'). When omitted, all categories are returned.
#
# .PARAMETER EntraIdRoleNamePrefix
# Prefix for generated Entra ID role names. Default is 'GloryRole'.
# Get-EntraIdRoleDisplayName appends either a descriptive suffix
# ("-{ResourceName} {Suffix}-{ClusterId}") or, when no descriptive
# name can be generated, a fallback suffix ("-EntraCluster-{ClusterId}"),
# so the default produces names like "GloryRole-User Manager-0" or
# "GloryRole-EntraCluster-0".
#
# .PARAMETER MinDistinctPrincipals
# Pruning threshold: minimum number of distinct principals that must
# have performed an action for it to be retained. Default is 2.
#
# .PARAMETER MinTotalCount
# Pruning threshold: minimum total count across all principals for an
# action to be retained. Default is 10.
#
# .PARAMETER ReadMode
# How to handle read-dominant actions. Valid values are 'Keep',
# 'DownWeight', and 'Exclude'. Default is 'DownWeight'.
#
# .PARAMETER ReadWeight
# Weight multiplier applied to read actions when ReadMode is
# 'DownWeight'. Default is 0.25.
#
# .PARAMETER UseTfIdf
# Switch to enable TF-IDF weighting before vectorization.
#
# .PARAMETER MinK
# Minimum number of clusters for Auto-K selection. Default is 2.
#
# .PARAMETER MaxK
# Maximum number of clusters for Auto-K selection. When set to 0 (the
# default), MaxK is auto-calculated by Invoke-AutoKSelection using
# Ceiling(Sqrt(N)*1.2). When an explicit positive value is provided,
# it is used directly.
#
# .PARAMETER Seed
# Random seed for deterministic clustering. Default is 42.
#
# .PARAMETER AssignableScopes
# Azure RBAC assignable scopes for generated role definitions. Default
# is @('/').
#
# .PARAMETER RoleNamePrefix
# Prefix for generated role names. Default is 'GloryRole-Cluster'.
#
# .INPUTS
# None. This script does not accept pipeline input.
#
# .OUTPUTS
# [pscustomobject] A pipeline result object with the following
# properties:
#   - RecommendedK ([int]): The cluster count selected by Auto-K
#   - Candidates ([object[]]): Array of candidate objects with metrics
#     for each evaluated K value
#   - ClusterActions ([object[]]): Array of cluster action sets, one per
#     cluster, each containing a ClusterId, an Actions array, and a
#     Principals array of contributing principal keys (e.g., UPNs,
#     object IDs, or application IDs)
#   - Quality ([pscustomobject]): Quality metrics for the ingested data
#     (Principals, Actions, NonZeroEntries, Density)
#   - OutputPath ([string]): The directory path where artifacts were
#     exported
#
# .EXAMPLE
# $objResult = & (Join-Path -Path $HOME -ChildPath 'repos/GloryRole/src/Invoke-RoleMiningPipeline.ps1') -InputMode CSV -CsvPath (Join-Path -Path $HOME -ChildPath 'data/counts.csv') -RoleSchema AzureRbac -OutputPath (Join-Path -Path $HOME -ChildPath 'output/role-mining')
#
# # Runs the pipeline in CSV mode with Azure RBAC output. The returned
# # object contains RecommendedK, Candidates, ClusterActions, Quality,
# # and OutputPath properties summarizing the role-mining results.
# # Emits role_cluster_<id>.json per cluster.
#
# .EXAMPLE
# $objResult = & (Join-Path -Path $HOME -ChildPath 'repos/GloryRole/src/Invoke-RoleMiningPipeline.ps1') -InputMode CSV -CsvPath (Join-Path -Path $HOME -ChildPath 'data/entra_counts.csv') -RoleSchema EntraId -OutputPath (Join-Path -Path $HOME -ChildPath 'output/entra-role-mining')
#
# # Runs the pipeline in CSV mode with Entra ID output. Useful for
# # demos and offline testing with a pre-canonicalized Entra sparse
# # triple CSV. Emits entra_role_cluster_<id>.json per cluster.
#
# .EXAMPLE
# $objResult = & (Join-Path -Path $HOME -ChildPath 'repos/GloryRole/src/Invoke-RoleMiningPipeline.ps1') -InputMode ActivityLog -SubscriptionIds @('00000000-0000-0000-0000-000000000001') -Start (Get-Date).AddDays(-30) -End (Get-Date) -OutputPath (Join-Path -Path $HOME -ChildPath 'output/role-mining')
#
# # Runs the pipeline in ActivityLog mode. Queries the Azure Activity
# # Log for the specified subscription over the last 30 days and
# # processes the results through the full pipeline. RoleSchema
# # defaults to 'AzureRbac' (Activity Log is a schema-constrained
# # source).
#
# .EXAMPLE
# $objResult = & (Join-Path -Path $HOME -ChildPath 'repos/GloryRole/src/Invoke-RoleMiningPipeline.ps1') -InputMode LogAnalytics -WorkspaceId '12345678-1234-1234-1234-123456789012' -RoleSchema AzureRbac -Start (Get-Date).AddDays(-30) -End (Get-Date) -OutputPath (Join-Path -Path $HOME -ChildPath 'output/role-mining')
#
# # Runs the pipeline in LogAnalytics mode with Azure RBAC output.
# # LogAnalytics is schema-neutral (the same workspace can hold Azure
# # Activity or Entra audit tables), so RoleSchema is required. When
# # AzureRbac, queries the AzureActivity table.
#
# .EXAMPLE
# $objResult = & (Join-Path -Path $HOME -ChildPath 'repos/GloryRole/src/Invoke-RoleMiningPipeline.ps1') -InputMode LogAnalytics -WorkspaceId '12345678-1234-1234-1234-123456789012' -RoleSchema EntraId -Start (Get-Date).AddDays(-30) -End (Get-Date) -OutputPath (Join-Path -Path $HOME -ChildPath 'output/entra-role-mining')
#
# # Runs the pipeline in LogAnalytics mode with Entra ID output.
# # Queries the AuditLogs table for Entra ID directory audit events,
# # maps activities to microsoft.directory/* actions (preserving
# # camelCase), and generates unifiedRoleDefinition JSON. The workspace
# # must receive Entra ID audit logs via diagnostic settings.
#
# .EXAMPLE
# $objResult = & (Join-Path -Path $HOME -ChildPath 'repos/GloryRole/src/Invoke-RoleMiningPipeline.ps1') -InputMode EntraId -Start (Get-Date).AddDays(-30) -End (Get-Date) -OutputPath (Join-Path -Path $HOME -ChildPath 'output/entra-role-mining')
#
# # Runs the pipeline in EntraId mode. Queries Microsoft Graph for
# # Entra ID directory audit logs over the last 30 days, clusters
# # admin activities, and generates Entra ID custom role definitions.
# # RoleSchema defaults to 'EntraId' (Graph directory audit is a
# # schema-constrained source).
#
# .NOTES
# Supported PowerShell versions:
#   - Windows PowerShell 5.1 (.NET Framework 4.6.2+)
#   - PowerShell 7.4.x
#   - PowerShell 7.5.x
#   - PowerShell 7.6.x
# Supported operating systems:
#   - Windows (all supported PowerShell versions)
#   - macOS (PowerShell 7.x only)
#   - Linux (PowerShell 7.x only)
#
# This script does not support positional parameters. All parameters
# must be specified by name (enforced by
# `[CmdletBinding(PositionalBinding = $false)]`).
#
# Version: 2.1.20260415.1

[CmdletBinding(PositionalBinding = $false)]
[OutputType([pscustomobject])]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('CSV', 'ActivityLog', 'LogAnalytics', 'EntraId')]
    [string]$InputMode,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [ValidateSet('AzureRbac', 'EntraId')]
    [string]$RoleSchema,

    [string]$CsvPath,

    [string[]]$SubscriptionIds,
    [datetime]$Start,
    [datetime]$End,
    [int]$InitialSliceHours = 24,
    [int]$MinSliceMinutes = 15,
    [int]$MaxRecordHint = 5000,

    [string]$WorkspaceId,

    [string[]]$EntraIdFilterCategory,
    [string]$EntraIdRoleNamePrefix = 'GloryRole',

    [int]$MinDistinctPrincipals = 2,
    [double]$MinTotalCount = 10,

    [ValidateSet('Keep', 'DownWeight', 'Exclude')]
    [string]$ReadMode = 'DownWeight',
    [double]$ReadWeight = 0.25,

    [switch]$UseTfIdf,

    [int]$MinK = 2,
    [int]$MaxK = 0,
    [int]$Seed = 42,

    [string[]]$AssignableScopes = @('/'),
    [string]$RoleNamePrefix = 'GloryRole-Cluster'
)

Set-StrictMode -Version Latest

#region SourceFiles ########################################################
# Dot-source all function files
$strScriptDirectory = $PSScriptRoot
. (Join-Path -Path $strScriptDirectory -ChildPath 'ConvertTo-NormalizedAction.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Resolve-PrincipalKey.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Get-StableSha256Hex.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'ConvertFrom-ClaimsJson.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Resolve-LocalizableStringValue.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'ConvertFrom-AzActivityLogRecord.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Get-AzActivityAdminEvent.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'ConvertTo-EntraIdResourceAction.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'ConvertFrom-EntraIdAuditRecord.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Get-EntraIdAuditEvent.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Get-EntraIdAuditEventFromLogAnalytics.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Import-PrincipalActionCountFromLogAnalytics.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Import-PrincipalActionCountFromCsv.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Remove-DuplicateCanonicalEvent.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'ConvertTo-PrincipalActionCount.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'ConvertTo-PrincipalDisplayNameMap.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Measure-PrincipalActionCountQuality.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Get-ActionStatFromCount.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Remove-RareAction.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Edit-ReadActionCount.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'ConvertTo-TfIdfCount.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'New-FeatureIndex.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'ConvertTo-VectorRow.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'ConvertTo-NormalizedVectorRow.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Get-SquaredEuclideanDistance.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Get-FarthestPointIndex.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Invoke-KMeansClustering.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Get-ApproximateSilhouetteScore.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Get-DaviesBouldinIndex.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Get-CalinskiHarabaszIndex.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Invoke-AutoKSelection.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Get-ClusterActionSet.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'New-AzureRoleDefinitionJson.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'New-EntraIdRoleDefinitionJson.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Get-EntraIdRoleDisplayName.ps1')
#endregion SourceFiles ########################################################

# Resolve OutputPath to an absolute path against PowerShell's $PWD so that
# downstream .NET File API calls (WriteAllLines / WriteAllText) do not
# resolve relative paths against [Environment]::CurrentDirectory, which may
# differ from $PWD (e.g. C:\windows\system32 on Windows).
$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)

# Ensure output directory exists
if (-not (Test-Path -LiteralPath $OutputPath)) {
    [void](New-Item -Path $OutputPath -ItemType Directory -Force)
}

# File writeability preflight
$strWriteTestPath = Join-Path -Path $OutputPath -ChildPath '.write_test'
try {
    [void](New-Item -Path $strWriteTestPath -ItemType File -Force -ErrorAction Stop)
    Remove-Item -LiteralPath $strWriteTestPath -Force -ErrorAction Stop
} catch {
    throw ("Cannot write to output directory '{0}': {1}" -f $OutputPath, $_.Exception.Message)
}

try {
    # Resolve -RoleSchema using default-where-constrained semantics.
    # Schema-constrained sources (ActivityLog, EntraId) default to the
    # only role schema they can meaningfully produce. Schema-neutral
    # sources (CSV, LogAnalytics) require the caller to state the
    # schema explicitly; the tool does not default to a particular
    # platform, so that CSV / LogAnalytics callers treating AzureRbac,
    # EntraId (and future AwsIam / GcpIam / ActiveDirectory) as equal
    # citizens are not silently routed to a default platform.
    if (-not $PSBoundParameters.ContainsKey('RoleSchema')) {
        switch ($InputMode) {
            'ActivityLog' { $RoleSchema = 'AzureRbac' }
            'EntraId' { $RoleSchema = 'EntraId' }
            default {
                throw ("RoleSchema is required when InputMode is '{0}'. Pass -RoleSchema 'AzureRbac' or -RoleSchema 'EntraId' to select which role-definition schema to emit." -f $InputMode)
            }
        }
    } else {
        # Compatibility check: schema-constrained sources reject
        # incompatible RoleSchema values so the caller gets a clear
        # error instead of silently producing a role-definition JSON
        # that the target API would reject.
        switch ($InputMode) {
            'ActivityLog' {
                if ($RoleSchema -ne 'AzureRbac') {
                    throw ("RoleSchema '{0}' is incompatible with InputMode 'ActivityLog'. The Azure Activity Log cmdlet only produces Azure RBAC actions, so only -RoleSchema 'AzureRbac' is valid (or omit -RoleSchema to use the default)." -f $RoleSchema)
                }
            }
            'EntraId' {
                if ($RoleSchema -ne 'EntraId') {
                    throw ("RoleSchema '{0}' is incompatible with InputMode 'EntraId'. Microsoft Graph directory audit logs only produce microsoft.directory/* actions, so only -RoleSchema 'EntraId' is valid (or omit -RoleSchema to use the default)." -f $RoleSchema)
                }
            }
        }
    }

    Write-Debug ("Parameters received: InputMode={0}, RoleSchema={1}, OutputPath={2}" -f $InputMode, $RoleSchema, $OutputPath)

    # Principal display-name lookup built during ingestion. Maps
    # PrincipalKey (GUID / AppId) to a human-readable name (UPN for
    # users, or the key itself for apps). Populated only for modes
    # that produce canonical events with PrincipalUPN metadata.
    $hashPrincipalDisplayName = @{}

    #region Stage 1: Ingest
    Write-Verbose "Stage 1: Ingesting data (mode: ${InputMode})..."

    $arrCounts = $null
    switch ($InputMode) {
        'CSV' {
            if ([string]::IsNullOrWhiteSpace($CsvPath)) {
                throw "CsvPath is required when InputMode is CSV."
            }
            $arrCounts = @(Import-PrincipalActionCountFromCsv -Path $CsvPath -RoleSchema $RoleSchema)
        }

        'ActivityLog' {
            if ($null -eq $SubscriptionIds -or $SubscriptionIds.Count -eq 0) {
                throw "SubscriptionIds is required when InputMode is ActivityLog."
            }
            if ($null -eq $Start -or $null -eq $End) {
                throw "Start and End are required when InputMode is ActivityLog."
            }

            $hashActivityLogParams = @{
                Start = $Start
                End = $End
                SubscriptionIds = $SubscriptionIds
                InitialSliceHours = $InitialSliceHours
                MinSliceMinutes = $MinSliceMinutes
                MaxRecordHint = $MaxRecordHint
                DetailedOutput = $true
            }
            $arrEvents = @(Get-AzActivityAdminEvent @hashActivityLogParams)

            Write-Verbose ("  Raw events collected: {0}" -f $arrEvents.Count)

            $arrDeduped = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)
            Write-Verbose ("  After deduplication: {0}" -f $arrDeduped.Count)

            # Build principal display-name lookup from deduplicated events.
            # Helper centralizes the UPN-preferred / PrincipalKey-fallback
            # precedence so both ActivityLog and EntraId branches stay in
            # lockstep if those rules change.
            $hashPrincipalDisplayName = ConvertTo-PrincipalDisplayNameMap -Events $arrDeduped
            Write-Verbose ("  Principal display names resolved: {0}" -f $hashPrincipalDisplayName.Count)

            $arrCounts = @(ConvertTo-PrincipalActionCount -Events $arrDeduped)
        }

        'LogAnalytics' {
            if ([string]::IsNullOrWhiteSpace($WorkspaceId)) {
                throw "WorkspaceId is required when InputMode is LogAnalytics."
            }
            if ($null -eq $Start -or $null -eq $End) {
                throw "Start and End are required when InputMode is LogAnalytics."
            }

            if ($RoleSchema -eq 'EntraId') {
                # Entra ID path: query the AuditLogs table, map
                # activities to microsoft.directory/* actions
                # PowerShell-side (preserves camelCase), then feed
                # canonical events through the same dedup -> display-
                # name -> count pipeline as the direct EntraId InputMode.
                $hashLogAnalyticsEntraParams = @{
                    WorkspaceId = $WorkspaceId
                    Start = $Start
                    End = $End
                }
                if ($null -ne $EntraIdFilterCategory -and $EntraIdFilterCategory.Count -gt 0) {
                    $hashLogAnalyticsEntraParams['FilterCategory'] = $EntraIdFilterCategory
                }
                $arrEvents = @(Get-EntraIdAuditEventFromLogAnalytics @hashLogAnalyticsEntraParams)

                Write-Verbose ("  Raw Entra ID events from Log Analytics: {0}" -f $arrEvents.Count)

                $arrDeduped = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)
                Write-Verbose ("  After deduplication: {0}" -f $arrDeduped.Count)

                $hashPrincipalDisplayName = ConvertTo-PrincipalDisplayNameMap -Events $arrDeduped
                Write-Verbose ("  Principal display names resolved: {0}" -f $hashPrincipalDisplayName.Count)

                $arrCounts = @(ConvertTo-PrincipalActionCount -Events $arrDeduped)
            } else {
                # Azure RBAC path: query the AzureActivity table with
                # pre-aggregation and lowercasing in KQL.
                $hashLogAnalyticsParams = @{
                    WorkspaceId = $WorkspaceId
                    Start = $Start
                    End = $End
                }
                $arrCounts = @(Import-PrincipalActionCountFromLogAnalytics @hashLogAnalyticsParams)
            }
        }

        'EntraId' {
            if ($null -eq $Start -or $null -eq $End) {
                throw "Start and End are required when InputMode is EntraId."
            }

            $hashEntraIdParams = @{
                Start = $Start
                End = $End
            }
            if ($null -ne $EntraIdFilterCategory -and $EntraIdFilterCategory.Count -gt 0) {
                $hashEntraIdParams['FilterCategory'] = $EntraIdFilterCategory
            }
            $arrEvents = @(Get-EntraIdAuditEvent @hashEntraIdParams)

            Write-Verbose ("  Raw Entra ID events collected: {0}" -f $arrEvents.Count)

            $arrDeduped = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)
            Write-Verbose ("  After deduplication: {0}" -f $arrDeduped.Count)

            # Build principal display-name map from Entra ID events.
            # Shares the same helper as the ActivityLog branch so
            # display-name precedence rules cannot drift between modes.
            $hashPrincipalDisplayName = ConvertTo-PrincipalDisplayNameMap -Events $arrDeduped
            Write-Verbose ("  Principal display names resolved: {0}" -f $hashPrincipalDisplayName.Count)

            $arrCounts = @(ConvertTo-PrincipalActionCount -Events $arrDeduped)
        }
    }

    Write-Verbose ("  Sparse triples loaded: {0}" -f $arrCounts.Count)

    if ($arrCounts.Count -eq 0) {
        # Provide mode-specific guidance so the user can diagnose common
        # root causes without needing to re-run with -Verbose.
        switch ($InputMode) {
            'ActivityLog' {
                $strIngestHint = ("No data was ingested from Azure Activity Log. Common causes: " +
                    "(1) not authenticated to Azure - run Connect-AzAccount; " +
                    "(2) the specified SubscriptionIds ({0}) had no Administrative category events between {1:yyyy-MM-dd} and {2:yyyy-MM-dd}; " +
                    "(3) none of the collected events had Status = 'Succeeded'; or " +
                    "(4) none of the events resolved to a principal and a normalized action. " +
                    "Re-run with -Verbose for per-subscription diagnostics.") -f ($SubscriptionIds -join ', '), $Start, $End
            }
            'LogAnalytics' {
                if ($RoleSchema -eq 'EntraId') {
                    $strIngestHint = ("No data was ingested from Log Analytics workspace '{0}' (AuditLogs table, RoleSchema=EntraId). Common causes: " +
                        "(1) not authenticated to Azure - run Connect-AzAccount; " +
                        "(2) the workspace does not receive Entra ID directory audit logs (check diagnostic settings); " +
                        "(3) the AuditLogs table had no successful events between {1:yyyy-MM-dd} and {2:yyyy-MM-dd}; " +
                        "(4) the specified FilterCategory values did not match any events; or " +
                        "(5) none of the activities mapped to a microsoft.directory/* action. " +
                        "Re-run with -Verbose for diagnostics.") -f $WorkspaceId, $Start, $End
                } else {
                    $strIngestHint = ("No data was ingested from Log Analytics workspace '{0}' (AzureActivity table, RoleSchema=AzureRbac). Common causes: " +
                        "(1) not authenticated to Azure - run Connect-AzAccount; " +
                        "(2) the workspace had no matching activity records between {1:yyyy-MM-dd} and {2:yyyy-MM-dd}; or " +
                        "(3) the workspace ID is incorrect or inaccessible. " +
                        "Re-run with -Verbose for diagnostics.") -f $WorkspaceId, $Start, $End
                }
            }
            'EntraId' {
                $strIngestHint = ("No data was ingested from Entra ID audit logs. Common causes: " +
                    "(1) not authenticated to Microsoft Graph - run Connect-MgGraph -Scopes 'AuditLog.Read.All'; " +
                    "(2) the tenant had no successful directory audit events between {0:yyyy-MM-dd} and {1:yyyy-MM-dd}; " +
                    "(3) the specified FilterCategory values did not match any events; or " +
                    "(4) none of the events resolved to a principal and a mapped action. " +
                    "Re-run with -Verbose for diagnostics.") -f $Start, $End
            }
            default {
                $strIngestHint = ("No data was ingested from CSV file '{0}'. Verify the file exists, " +
                    "contains the expected PrincipalKey/Action/Count columns, and has at least one data row.") -f $CsvPath
            }
        }
        throw $strIngestHint
    }
    #endregion Stage 1: Ingest

    #region Stage 2: Quality Gate
    Write-Verbose "Stage 2: Quality gate..."

    $objQuality = Measure-PrincipalActionCountQuality -Counts $arrCounts

    Write-Verbose ("  Principals: {0}, Actions: {1}, Non-zero: {2}, Density: {3:P2}" -f $objQuality.Principals, $objQuality.Actions, $objQuality.NonZeroEntries, $objQuality.Density)

    Write-Debug ("Quality metrics: Principals={0}, Actions={1}, NonZeroEntries={2}, Density={3}" -f $objQuality.Principals, $objQuality.Actions, $objQuality.NonZeroEntries, $objQuality.Density)

    if ($objQuality.Principals -lt 2) {
        throw "Insufficient data: need at least 2 principals for clustering."
    }
    #endregion Stage 2: Quality Gate

    #region Stage 3: Prune rare actions
    Write-Verbose "Stage 3: Pruning rare actions..."

    $intInputTripleCount = $arrCounts.Count

    $hashPruneParams = @{
        Counts = $arrCounts
        MinDistinctPrincipals = $MinDistinctPrincipals
        MinTotalCount = $MinTotalCount
    }
    $objPruneResult = Remove-RareAction @hashPruneParams

    $arrCounts = $objPruneResult.Kept
    $arrDropped = $objPruneResult.Dropped

    Write-Verbose ("  Kept: {0} triples, Dropped: {1} triples" -f $arrCounts.Count, $arrDropped.Count)

    if ($arrCounts.Count -eq 0) {
        # Summarize the best-performing actions so the user can see how close
        # their data was to clearing the thresholds and choose sensible new
        # values, rather than guessing blindly.
        $intMaxDistinctPrincipals = 0
        $dblMaxTotalCount = 0.0
        if ($null -ne $objPruneResult.Stats -and $objPruneResult.Stats.Count -gt 0) {
            $objMaxPrincipals = $objPruneResult.Stats | Measure-Object -Property DistinctPrincipals -Maximum
            $objMaxTotal = $objPruneResult.Stats | Measure-Object -Property TotalCount -Maximum
            if ($null -ne $objMaxPrincipals.Maximum) {
                $intMaxDistinctPrincipals = [int]$objMaxPrincipals.Maximum
            }
            if ($null -ne $objMaxTotal.Maximum) {
                $dblMaxTotalCount = [double]$objMaxTotal.Maximum
            }
        }

        # Parenthesized multi-line concat (PSScriptAnalyzer's
        # PSUseConsistentIndentation tolerates continuation inside
        # parens but flags it for bare operator continuation). -f is
        # placed on the same line as the closing paren so no backtick
        # is needed.
        $strPruneHint = ("All actions were pruned. Input to stage 3 had {0} triple(s) covering {1} principal(s) and {2} distinct action(s). " +
            "No action met BOTH thresholds (MinDistinctPrincipals={3}, MinTotalCount={4}). " +
            "The most-covered action was seen by {5} distinct principal(s); the highest total count for any single action was {6}. " +
            "Lower -MinDistinctPrincipals and/or -MinTotalCount (or widen the time range / add subscriptions), then retry. Re-run with -Verbose for per-stage diagnostics.") -f $intInputTripleCount, $objQuality.Principals, $objQuality.Actions, $MinDistinctPrincipals, $MinTotalCount, $intMaxDistinctPrincipals, $dblMaxTotalCount

        # When no action is shared by more than one principal, the dataset
        # lacks the overlap that clustering exploits. Call this out
        # explicitly because it typically indicates a thin test environment
        # or a too-narrow time window, not a configuration problem that
        # lowering thresholds alone can fix.
        if ($intMaxDistinctPrincipals -le 1) {
            $strPruneHint = $strPruneHint + " NOTE: No action was performed by more than one principal, so principals have no shared activity. Clustering requires shared actions; consider widening the time range, adding more subscriptions, or using a production environment with real admin activity."
        }

        throw $strPruneHint
    }
    #endregion Stage 3: Prune rare actions

    #region Stage 4: Read-dominance handling
    Write-Verbose ("Stage 4: Read handling (mode: {0})..." -f $ReadMode)

    $arrCounts = @(Edit-ReadActionCount -Counts $arrCounts -Mode $ReadMode -ReadWeight $ReadWeight)
    #endregion Stage 4: Read-dominance handling

    #region Stage 5: Optional TF-IDF
    if ($UseTfIdf) {
        Write-Verbose "Stage 5: Applying TF-IDF weighting..."
        $arrCounts = @(ConvertTo-TfIdfCount -Counts $arrCounts)
    }
    #endregion Stage 5: Optional TF-IDF

    #region Stage 6: Vectorize
    Write-Verbose "Stage 6: Building feature index and vectors..."

    $objFeatureIndex = New-FeatureIndex -PrincipalActionCounts $arrCounts
    $arrVectorRows = @(ConvertTo-VectorRow -Counts $arrCounts -FeatureIndexObject $objFeatureIndex)

    Write-Verbose ("  Features: {0}, Principals: {1}" -f $objFeatureIndex.FeatureNames.Count, $arrVectorRows.Count)
    #endregion Stage 6: Vectorize

    #region Stage 7: Normalize
    Write-Verbose "Stage 7: Normalizing vectors (Log1P + L2)..."

    $arrVectorRows = @(ConvertTo-NormalizedVectorRow -VectorRows $arrVectorRows)
    #endregion Stage 7: Normalize

    #region Stage 8: Auto-K Clustering
    Write-Verbose "Stage 8: Running Auto-K selection..."

    $hashAutoKParams = @{
        VectorRows = $arrVectorRows
        MinK = $MinK
        MaxK = $MaxK
        Seed = $Seed
    }
    $objAutoK = Invoke-AutoKSelection @hashAutoKParams

    Write-Verbose ("  Recommended K: {0}" -f $objAutoK.RecommendedK)
    Write-Debug ("Auto-K result: RecommendedK={0}, CandidateCount={1}" -f $objAutoK.RecommendedK, $objAutoK.Candidates.Count)
    Write-Verbose "  Candidate scores:"
    foreach ($objCandidate in $objAutoK.Candidates) {
        Write-Verbose ("    K={0}: SSE={1:F4}, Sil={2:F4}, DB={3:F4}, CH={4:F2}, Composite={5:F4}" -f $objCandidate.K, $objCandidate.SSE, $objCandidate.Silhouette, $objCandidate.DaviesBouldin, $objCandidate.CalinskiHarabasz, $objCandidate.CompositeRank)
    }
    #endregion Stage 8: Auto-K Clustering

    #region Stage 9: Generate cluster action sets
    Write-Verbose "Stage 9: Generating cluster action sets..."

    # Use original (pre-TF-IDF) counts for action extraction to maintain RBAC
    # fidelity. Re-load from pruned+read-handled counts by re-applying
    # Edit-ReadActionCount to the pruned set if TF-IDF was used. Since we
    # overwrote $arrCounts, use the cluster assignments against the current
    # counts which still have the correct PrincipalKey->Action mapping.
    $hashClusterActionParams = @{
        Counts = $arrCounts
        AssignmentsMap = $objAutoK.BestModel.Assignments
    }
    if ($hashPrincipalDisplayName.Count -gt 0) {
        $hashClusterActionParams['PrincipalDisplayNameMap'] = $hashPrincipalDisplayName
    }
    $arrClusterActions = @(Get-ClusterActionSet @hashClusterActionParams)
    #endregion Stage 9: Generate cluster action sets

    #region Stage 10: Export artifacts
    Write-Verbose "Stage 10: Exporting artifacts..."

    # Use UTF-8 without BOM for every generated artifact so the output
    # is byte-identical across Windows PowerShell 5.1 and PowerShell
    # 7+. Set-Content / Export-Csv / Out-File defaults differ between
    # those hosts (Windows PowerShell 5.1 emits ANSI/ASCII by default
    # for some cmdlets and UTF-16LE for others), so the pipeline
    # bypasses those cmdlets and writes every artifact through the
    # .NET File API with a single shared encoding.
    $objUtf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)

    # principal_action_counts.csv
    $strCountsPath = Join-Path -Path $OutputPath -ChildPath 'principal_action_counts.csv'
    $arrCountsCsvLines = @($arrCounts | ConvertTo-Csv -NoTypeInformation)
    [System.IO.File]::WriteAllLines($strCountsPath, [string[]]$arrCountsCsvLines, $objUtf8NoBomEncoding)
    Write-Verbose ("  Exported: {0}" -f $strCountsPath)

    # features.txt
    $strFeaturesPath = Join-Path -Path $OutputPath -ChildPath 'features.txt'
    $arrFeatureLines = @($objFeatureIndex.FeatureNames)
    [System.IO.File]::WriteAllLines($strFeaturesPath, [string[]]$arrFeatureLines, $objUtf8NoBomEncoding)
    Write-Verbose ("  Exported: {0}" -f $strFeaturesPath)

    # quality.json
    $strQualityPath = Join-Path -Path $OutputPath -ChildPath 'quality.json'
    $strQualityJson = $objQuality |
        Select-Object -Property Principals, Actions, NonZeroEntries, Density |
        ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($strQualityPath, [string]$strQualityJson, $objUtf8NoBomEncoding)
    Write-Verbose ("  Exported: {0}" -f $strQualityPath)

    # autoK_candidates.csv
    $strAutoKPath = Join-Path -Path $OutputPath -ChildPath 'autoK_candidates.csv'
    $arrAutoKCsvLines = @($objAutoK.Candidates | ConvertTo-Csv -NoTypeInformation)
    [System.IO.File]::WriteAllLines($strAutoKPath, [string[]]$arrAutoKCsvLines, $objUtf8NoBomEncoding)
    Write-Verbose ("  Exported: {0}" -f $strAutoKPath)

    # clusters.json
    $strClustersPath = Join-Path -Path $OutputPath -ChildPath 'clusters.json'
    $strClustersJson = $arrClusterActions | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($strClustersPath, [string]$strClustersJson, $objUtf8NoBomEncoding)
    Write-Verbose ("  Exported: {0}" -f $strClustersPath)

    # Role JSON per cluster. Gated on $RoleSchema (not $InputMode) so
    # that schema-neutral sources (CSV, LogAnalytics) can emit either
    # Azure RBAC or Entra ID role definitions based on the caller's
    # explicit -RoleSchema choice.
    if ($RoleSchema -eq 'EntraId') {
        # Entra ID custom role definitions (unifiedRoleDefinition format).
        foreach ($objCluster in $arrClusterActions) {
            $strRoleName = Get-EntraIdRoleDisplayName -ResourceActions $objCluster.Actions -ClusterId $objCluster.ClusterId -Prefix $EntraIdRoleNamePrefix
            $strDescription = ("Auto-generated least-privilege Entra ID role from cluster {0} with {1} resource actions." -f $objCluster.ClusterId, $objCluster.Actions.Count)

            $hashRoleParams = @{
                RoleName = $strRoleName
                Description = $strDescription
                ResourceActions = $objCluster.Actions
            }
            $strRoleJson = New-EntraIdRoleDefinitionJson @hashRoleParams

            $strRolePath = Join-Path -Path $OutputPath -ChildPath ("entra_role_cluster_{0}.json" -f $objCluster.ClusterId)
            [System.IO.File]::WriteAllText($strRolePath, $strRoleJson, $objUtf8NoBomEncoding)
            Write-Verbose ("  Exported: {0}" -f $strRolePath)
        }
    } else {
        # Azure RBAC custom role definitions.
        foreach ($objCluster in $arrClusterActions) {
            $strRoleName = ("{0}-{1}" -f $RoleNamePrefix, $objCluster.ClusterId)
            $strDescription = ("Auto-generated least-privilege role from cluster {0} with {1} actions." -f $objCluster.ClusterId, $objCluster.Actions.Count)

            $hashRoleParams = @{
                RoleName = $strRoleName
                Description = $strDescription
                Actions = $objCluster.Actions
                AssignableScopes = $AssignableScopes
            }
            $strRoleJson = New-AzureRoleDefinitionJson @hashRoleParams

            $strRolePath = Join-Path -Path $OutputPath -ChildPath ("role_cluster_{0}.json" -f $objCluster.ClusterId)
            [System.IO.File]::WriteAllText($strRolePath, $strRoleJson, $objUtf8NoBomEncoding)
            Write-Verbose ("  Exported: {0}" -f $strRolePath)
        }
    }
    #endregion Stage 10: Export artifacts

    #region Summary
    Write-Verbose "Pipeline complete."

    [pscustomobject]@{
        RecommendedK = $objAutoK.RecommendedK
        Candidates = $objAutoK.Candidates
        ClusterActions = $arrClusterActions
        Quality = $objQuality
        OutputPath = $OutputPath
    }
    #endregion Summary
} catch {
    Write-Debug ("Invoke-RoleMiningPipeline failed: {0}" -f $(if ($_.Exception.Message) { $_.Exception.Message } else { $_.ToString() }))
    throw
}
