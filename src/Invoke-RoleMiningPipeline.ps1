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
# Mandatory. Selects the data ingestion mode. Valid values are 'CSV',
# 'ActivityLog', and 'LogAnalytics'.
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
# Required when InputMode is 'ActivityLog' or 'LogAnalytics'. Start of
# the time window for data collection.
#
# .PARAMETER End
# Required when InputMode is 'ActivityLog' or 'LogAnalytics'. End of
# the time window for data collection.
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
#     Principals array listing the contributing users and service
#     principals
#   - Quality ([pscustomobject]): Quality metrics for the ingested data
#     (Principals, Actions, NonZeroEntries, Density)
#   - OutputPath ([string]): The directory path where artifacts were
#     exported
#
# .EXAMPLE
# $objResult = & (Join-Path -Path $HOME -ChildPath 'repos/GloryRole/src/Invoke-RoleMiningPipeline.ps1') -InputMode CSV -CsvPath (Join-Path -Path $HOME -ChildPath 'data/counts.csv') -OutputPath (Join-Path -Path $HOME -ChildPath 'output/role-mining')
#
# # Runs the pipeline in CSV mode. The returned object contains
# # RecommendedK, Candidates, ClusterActions, Quality, and OutputPath
# # properties summarizing the role-mining results.
#
# .EXAMPLE
# $objResult = & (Join-Path -Path $HOME -ChildPath 'repos/GloryRole/src/Invoke-RoleMiningPipeline.ps1') -InputMode ActivityLog -SubscriptionIds @('00000000-0000-0000-0000-000000000001') -Start (Get-Date).AddDays(-30) -End (Get-Date) -OutputPath (Join-Path -Path $HOME -ChildPath 'output/role-mining')
#
# # Runs the pipeline in ActivityLog mode. Queries the Azure Activity
# # Log for the specified subscription over the last 30 days and
# # processes the results through the full pipeline.
#
# .EXAMPLE
# $objResult = & (Join-Path -Path $HOME -ChildPath 'repos/GloryRole/src/Invoke-RoleMiningPipeline.ps1') -InputMode LogAnalytics -WorkspaceId '12345678-1234-1234-1234-123456789012' -Start (Get-Date).AddDays(-30) -End (Get-Date) -OutputPath (Join-Path -Path $HOME -ChildPath 'output/role-mining')
#
# # Runs the pipeline in LogAnalytics mode. Queries the specified Log
# # Analytics workspace for activity data over the last 30 days and
# # processes the results through the full pipeline.
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
# This script supports positional parameters in declaration order.
# Position 0: InputMode
# Position 1: OutputPath
# All remaining parameters should be specified by name.
#
# Version: 1.3.20260413.0

[CmdletBinding()]
[OutputType([pscustomobject])]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('CSV', 'ActivityLog', 'LogAnalytics')]
    [string]$InputMode,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$CsvPath,

    [string[]]$SubscriptionIds,
    [datetime]$Start,
    [datetime]$End,
    [int]$InitialSliceHours = 24,
    [int]$MinSliceMinutes = 15,
    [int]$MaxRecordHint = 5000,

    [string]$WorkspaceId,

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
. (Join-Path -Path $strScriptDirectory -ChildPath 'Import-PrincipalActionCountFromLogAnalytics.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Import-PrincipalActionCountFromCsv.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'Remove-DuplicateCanonicalEvent.ps1')
. (Join-Path -Path $strScriptDirectory -ChildPath 'ConvertTo-PrincipalActionCount.ps1')
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
#endregion SourceFiles ########################################################

# Ensure output directory exists
if (-not (Test-Path -Path $OutputPath)) {
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
    Write-Debug ("Parameters received: InputMode={0}, OutputPath={1}" -f $InputMode, $OutputPath)

    #region Stage 1: Ingest
    Write-Verbose "Stage 1: Ingesting data (mode: ${InputMode})..."

    $arrCounts = $null
    switch ($InputMode) {
        'CSV' {
            if ([string]::IsNullOrWhiteSpace($CsvPath)) {
                throw "CsvPath is required when InputMode is CSV."
            }
            $arrCounts = @(Import-PrincipalActionCountFromCsv -Path $CsvPath)
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

            $arrCounts = @(ConvertTo-PrincipalActionCount -Events $arrDeduped)
        }

        'LogAnalytics' {
            if ([string]::IsNullOrWhiteSpace($WorkspaceId)) {
                throw "WorkspaceId is required when InputMode is LogAnalytics."
            }
            if ($null -eq $Start -or $null -eq $End) {
                throw "Start and End are required when InputMode is LogAnalytics."
            }

            $hashLogAnalyticsParams = @{
                WorkspaceId = $WorkspaceId
                Start = $Start
                End = $End
            }
            $arrCounts = @(Import-PrincipalActionCountFromLogAnalytics @hashLogAnalyticsParams)
        }
    }

    Write-Verbose ("  Sparse triples loaded: {0}" -f $arrCounts.Count)

    if ($arrCounts.Count -eq 0) {
        throw "No data was ingested. Check your input parameters."
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
        throw "All actions were pruned. Lower the pruning thresholds."
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
    $arrClusterActions = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $objAutoK.BestModel.Assignments)
    #endregion Stage 9: Generate cluster action sets

    #region Stage 10: Export artifacts
    Write-Verbose "Stage 10: Exporting artifacts..."

    # principal_action_counts.csv
    $strCountsPath = Join-Path -Path $OutputPath -ChildPath 'principal_action_counts.csv'
    $arrCounts | Export-Csv -Path $strCountsPath -NoTypeInformation
    Write-Verbose ("  Exported: {0}" -f $strCountsPath)

    # features.txt
    $strFeaturesPath = Join-Path -Path $OutputPath -ChildPath 'features.txt'
    $objFeatureIndex.FeatureNames | Set-Content -Path $strFeaturesPath
    Write-Verbose ("  Exported: {0}" -f $strFeaturesPath)

    # quality.json
    $strQualityPath = Join-Path -Path $OutputPath -ChildPath 'quality.json'
    $objQuality | Select-Object -Property Principals, Actions, NonZeroEntries, Density |
        ConvertTo-Json -Depth 4 |
        Set-Content -Path $strQualityPath
    Write-Verbose ("  Exported: {0}" -f $strQualityPath)

    # autoK_candidates.csv
    $strAutoKPath = Join-Path -Path $OutputPath -ChildPath 'autoK_candidates.csv'
    $objAutoK.Candidates | Export-Csv -Path $strAutoKPath -NoTypeInformation
    Write-Verbose ("  Exported: {0}" -f $strAutoKPath)

    # clusters.json
    $strClustersPath = Join-Path -Path $OutputPath -ChildPath 'clusters.json'
    $arrClusterActions | ConvertTo-Json -Depth 4 | Set-Content -Path $strClustersPath
    Write-Verbose ("  Exported: {0}" -f $strClustersPath)

    # Role JSON per cluster
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
        $strRoleJson | Set-Content -Path $strRolePath
        Write-Verbose ("  Exported: {0}" -f $strRolePath)
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
