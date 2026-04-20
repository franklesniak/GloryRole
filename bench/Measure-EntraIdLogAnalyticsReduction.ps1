# .SYNOPSIS
# Measures Entra ID Log Analytics ingestion pipeline performance
# using synthetic fixtures.
# .DESCRIPTION
# Generates synthetic audit log fixtures at various duplicate ratios,
# runs them through the stage-1 pipeline segment
# (Get-EntraIdAuditEventFromLogAnalytics -> Remove-DuplicateCanonicalEvent
# -> ConvertTo-PrincipalDisplayNameMap -> ConvertTo-PrincipalActionCount),
# and records wall-clock timing and memory metrics to a CSV file.
#
# This script is opt-in and not part of the default Pester run. It runs
# entirely offline with no Azure dependency.
# .NOTES
# Requires the following source files from src/:
#   ConvertTo-EntraIdResourceAction.ps1
#   Get-EntraIdAuditEventFromLogAnalytics.ps1
#   Remove-DuplicateCanonicalEvent.ps1
#   ConvertTo-PrincipalDisplayNameMap.ps1
#   ConvertTo-PrincipalActionCount.ps1
#
# Requires the fixture generator from tests/PowerShell/_fixtures/:
#   New-SyntheticAuditLogFixture.ps1
#
# Version: 1.1.20260420.0

[CmdletBinding()]
param (
    [ValidateRange(1, [int]::MaxValue)]
    [int]$FixtureSize = 10000,

    [double[]]$DuplicateRatios = @(0.0, 0.25, 0.5),

    [ValidateRange(1, [int]::MaxValue)]
    [int]$Iterations = 3,

    [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath 'results'),

    [string]$Label = 'baseline',

    [int]$Seed = 42
)

Set-StrictMode -Version Latest

#region Load dependencies
$strRepoRoot = Split-Path -Path $PSScriptRoot -Parent
$strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'
$strFixturesPath = Join-Path -Path $strRepoRoot -ChildPath 'tests'
$strFixturesPath = Join-Path -Path $strFixturesPath -ChildPath 'PowerShell'
$strFixturesPath = Join-Path -Path $strFixturesPath -ChildPath '_fixtures'

. (Join-Path -Path $strFixturesPath -ChildPath 'New-SyntheticAuditLogFixture.ps1')
. (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-EntraIdResourceAction.ps1')
. (Join-Path -Path $strSrcPath -ChildPath 'Get-EntraIdAuditEventFromLogAnalytics.ps1')
. (Join-Path -Path $strSrcPath -ChildPath 'Remove-DuplicateCanonicalEvent.ps1')
. (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-PrincipalDisplayNameMap.ps1')
. (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-PrincipalActionCount.ps1')

# Stub function for Invoke-AzOperationalInsightsQuery so the benchmark
# can run offline without the Az.OperationalInsights module.
function Invoke-AzOperationalInsightsQuery {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters exist to mirror the stubbed cmdlet signature.')]
    [CmdletBinding()]
    param ($WorkspaceId, $Query)
}
#endregion Load dependencies

#region Ensure output directory exists
$strOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if (-not (Test-Path -LiteralPath $strOutputPath)) {
    [void]([System.IO.Directory]::CreateDirectory($strOutputPath))
}
#endregion Ensure output directory exists

#region Run benchmark iterations
$listResults = New-Object System.Collections.Generic.List[pscustomobject]

foreach ($dblDupRatio in $DuplicateRatios) {
    for ($intIter = 1; $intIter -le $Iterations; $intIter++) {
        Write-Verbose ("Running: FixtureSize={0}, DuplicateRatio={1}, Iteration={2}/{3}" -f $FixtureSize, $dblDupRatio, $intIter, $Iterations)

        # Generate fixture
        $arrFixture = @(New-SyntheticAuditLogFixture -Count $FixtureSize -DuplicateRatio $dblDupRatio -Seed $Seed)

        # Mock Invoke-AzOperationalInsightsQuery to return the fixture
        $script:arrBenchFixture = $arrFixture
        function Invoke-AzOperationalInsightsQuery {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSReviewUnusedParameter', '',
                Justification = 'Parameters exist to mirror the stubbed cmdlet signature.')]
            [CmdletBinding()]
            param ($WorkspaceId, $Query)
            return [pscustomobject]@{ Results = $script:arrBenchFixture }
        }

        # Time the stage-1 pipeline
        $objStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $hashUnmapped = @{}
        $arrEvents = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId 'bench-workspace' -Start ([datetime]'2025-12-01') -End ([datetime]'2026-01-16') -UnmappedActivityAccumulator $hashUnmapped)
        $arrDeduped = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)
        $hashDisplayNames = ConvertTo-PrincipalDisplayNameMap -Events $arrDeduped
        $arrCounts = @(ConvertTo-PrincipalActionCount -Events $arrDeduped)

        $objStopwatch.Stop()

        # Suppress unused variable warnings
        [void]$hashDisplayNames
        [void]$hashUnmapped

        # WorkingSet64 (not PeakWorkingSet64) gives the current process working
        # set at the end of this iteration. PeakWorkingSet64 is the lifetime
        # peak across the whole process, so it would leak across iterations and
        # make per-(FixtureSize, DuplicateRatio) comparisons misleading.
        $intWorkingSet = [System.Diagnostics.Process]::GetCurrentProcess().WorkingSet64

        [void]($listResults.Add([pscustomobject]@{
                    FixtureSize = $FixtureSize
                    DuplicateRatio = $dblDupRatio
                    Iteration = $intIter
                    RowsReturnedByMock = $arrFixture.Count
                    EventsEmittedFromIngestion = $arrEvents.Count
                    TriplesAfterStageOne = $arrCounts.Count
                    StageOneWallClockMs = $objStopwatch.ElapsedMilliseconds
                    WorkingSetBytes = $intWorkingSet
                }))
    }
}
#endregion Run benchmark iterations

#region Write CSV output
$strTimestamp = [datetime]::UtcNow.ToString('yyyyMMdd-HHmmss', [System.Globalization.CultureInfo]::InvariantCulture)
$strCsvFilename = ('{0}-{1}.csv' -f $Label, $strTimestamp)
$strCsvPath = Join-Path -Path $strOutputPath -ChildPath $strCsvFilename

$objUtf8NoBom = New-Object System.Text.UTF8Encoding($false)
$arrCsvLines = New-Object System.Collections.Generic.List[string]
[void]($arrCsvLines.Add('FixtureSize,DuplicateRatio,Iteration,RowsReturnedByMock,EventsEmittedFromIngestion,TriplesAfterStageOne,StageOneWallClockMs,WorkingSetBytes'))
foreach ($objRow in $listResults) {
    [void]($arrCsvLines.Add(('{0},{1},{2},{3},{4},{5},{6},{7}' -f $objRow.FixtureSize, $objRow.DuplicateRatio, $objRow.Iteration, $objRow.RowsReturnedByMock, $objRow.EventsEmittedFromIngestion, $objRow.TriplesAfterStageOne, $objRow.StageOneWallClockMs, $objRow.WorkingSetBytes)))
}
[System.IO.File]::WriteAllLines(
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($strCsvPath),
    $arrCsvLines.ToArray(),
    $objUtf8NoBom
)

Write-Verbose ("Results written to: {0}" -f $strCsvPath)
#endregion Write CSV output

#region Emit Markdown summary
Write-Output ""
Write-Output "## Benchmark Summary"
Write-Output ""
Write-Output "| DuplicateRatio | MedianWallClockMs | P95WallClockMs | MedianRowsReturned | TriplesProduced |"
Write-Output "|---|---|---|---|---|"

foreach ($dblDupRatio in $DuplicateRatios) {
    $arrSubset = @($listResults | Where-Object { $_.DuplicateRatio -eq $dblDupRatio })
    if ($arrSubset.Count -eq 0) {
        continue
    }

    # Calculate median and P95 for wall clock
    $arrWallClockSorted = @($arrSubset | Sort-Object StageOneWallClockMs | Select-Object -ExpandProperty StageOneWallClockMs)
    $intMedianIndex = [Math]::Floor($arrWallClockSorted.Count / 2)
    $intMedianWallClock = $arrWallClockSorted[$intMedianIndex]

    $intP95Index = [Math]::Min([Math]::Ceiling($arrWallClockSorted.Count * 0.95) - 1, $arrWallClockSorted.Count - 1)
    $intP95WallClock = $arrWallClockSorted[$intP95Index]

    # Median rows returned
    $arrRowsSorted = @($arrSubset | Sort-Object EventsEmittedFromIngestion | Select-Object -ExpandProperty EventsEmittedFromIngestion)
    $intMedianRows = $arrRowsSorted[$intMedianIndex]

    # Take TriplesProduced from first iteration (deterministic, same across iterations)
    $intTriples = $arrSubset[0].TriplesAfterStageOne

    Write-Output ("| {0} | {1} | {2} | {3} | {4} |" -f $dblDupRatio, $intMedianWallClock, $intP95WallClock, $intMedianRows, $intTriples)
}

Write-Output ""
Write-Output ("Label: {0}, FixtureSize: {1}, Iterations: {2}, Seed: {3}" -f $Label, $FixtureSize, $Iterations, $Seed)
#endregion Emit Markdown summary
