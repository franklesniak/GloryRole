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
# Version: 1.3.20260423.0

[CmdletBinding()]
param (
    [ValidateRange(1, [int]::MaxValue)]
    [int]$FixtureSize = 10000,

    [ValidateRange(0.0, 0.95)]
    [double[]]$DuplicateRatios = @(0.0, 0.25, 0.5),

    [ValidateRange(1, [int]::MaxValue)]
    [int]$Iterations = 3,

    [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath 'results'),

    [string]$Label = 'baseline',

    [int]$Seed = 42,

    # Mode selector (opt-in, additive).
    # - Legacy (default): preserves the pre-existing benchmark behaviour. The
    #   mock Invoke-AzOperationalInsightsQuery returns the entire fixture to
    #   every chunk without time-window filtering and without any server-side
    #   collapse. This is retained for byte-exact backward compatibility with
    #   earlier invocations of this script.
    # - Baseline: simulates the pre-Option-A path. The mock filters by the
    #   chunk's KQL time window but applies no server-side retry collapse;
    #   emitted row counts reflect what the ingestion function would see if
    #   the KQL omitted the arg_min summarize block.
    # - OptionA: simulates the current production KQL's server-side
    #   retry-collapse applied GLOBALLY across [Start, End] (i.e., as if the
    #   whole range were a single chunk). The collapse is performed once on
    #   the entire fixture up front; the mock then filters the collapsed
    #   rows by each chunk's time window. This isolates the Option A gain
    #   from the Option B chunking contribution.
    # - OptionAPlusB: matches the current production behaviour. The mock
    #   filters raw fixture rows by each chunk's time window first, then
    #   applies the Option A collapse PER CHUNK. Retry duplicates whose
    #   timestamps straddle an internal chunk boundary survive the per-chunk
    #   collapse and are removed downstream by Remove-DuplicateCanonicalEvent.
    [ValidateSet('Legacy', 'Baseline', 'OptionA', 'OptionAPlusB')]
    [string]$Mode = 'Legacy'
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

# Mode helper: filter a fixture set by the KQL chunk time window. Mirrors
# Select-MockRowByKqlTimeWindow in the equivalence tests: parses the first
# two datetime(...) tokens from the query, detects the half-open vs. closed
# upper bound, and returns only rows whose TimeGenerated falls in that
# window. Rows with unparseable TimeGenerated are treated the same way as
# the equivalence tests: included only on terminal (closed-upper) chunks.
function Select-BenchRowByKqlTimeWindow {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = 'Function returns a collection of mock rows; plural "Row" matches repository convention for collection-returning helpers (e.g., Select-MockRowByKqlTimeWindow in the equivalence suite).')]
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Query,
        [object[]]$Rows
    )

    if ($null -eq $Rows -or $Rows.Count -eq 0) {
        return @()
    }

    $regexDt = [regex]'datetime\(([^)]+)\)'
    $objMatches = $regexDt.Matches($Query)
    if ($objMatches.Count -lt 2) {
        return @($Rows)
    }

    $dtStyles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    $objCulture = [System.Globalization.CultureInfo]::InvariantCulture
    $dtLower = [datetime]::Parse($objMatches[0].Groups[1].Value, $objCulture, $dtStyles)
    $dtUpper = [datetime]::Parse($objMatches[1].Groups[1].Value, $objCulture, $dtStyles)

    $boolClosedUpper = $false
    if ($Query -match '<=\s*datetime\(') {
        $boolClosedUpper = $true
    }

    $listFiltered = New-Object System.Collections.Generic.List[object]
    foreach ($objRow in $Rows) {
        $strTg = [string]$objRow.TimeGenerated
        if ([string]::IsNullOrWhiteSpace($strTg)) {
            if ($boolClosedUpper) {
                [void]($listFiltered.Add($objRow))
            }
            continue
        }
        $dtRowParsed = [datetime]::MinValue
        $boolRowParsed = [datetime]::TryParse($strTg, $objCulture, $dtStyles, [ref]$dtRowParsed)
        if (-not $boolRowParsed) {
            if ($boolClosedUpper) {
                [void]($listFiltered.Add($objRow))
            }
            continue
        }
        if ($dtRowParsed -lt $dtLower) { continue }
        if ($boolClosedUpper) {
            if ($dtRowParsed -gt $dtUpper) { continue }
        } else {
            if ($dtRowParsed -ge $dtUpper) { continue }
        }
        [void]($listFiltered.Add($objRow))
    }
    return $listFiltered.ToArray()
}

# Mode helper: simulate the Option A server-side retry-collapse on an
# already-time-filtered set of fixture rows. Rows with a whitespace-only,
# empty, or null CorrelationId bypass the collapse (union branch); other
# rows are reduced per (PrincipalKey, OperationName, CorrelationId) to the
# earliest TimeGenerated (arg_min semantics). Mirrors the KQL in
# Get-EntraIdAuditEventFromLogAnalytics.ps1 and the
# Invoke-OptionAServerSideCollapse helper in the equivalence tests.
function Invoke-BenchOptionACollapse {
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Rows
    )

    if ($null -eq $Rows -or $Rows.Count -eq 0) {
        return @()
    }

    $hashtableSeen = @{}
    $arrSorted = @($Rows | Sort-Object TimeGenerated)
    $listOut = New-Object System.Collections.Generic.List[object]

    foreach ($objRow in $arrSorted) {
        $strCorrelationId = ''
        if ($null -ne $objRow.CorrelationId) {
            $strCorrelationId = [string]$objRow.CorrelationId
        }

        if ([string]::IsNullOrWhiteSpace($strCorrelationId)) {
            [void]($listOut.Add($objRow))
            continue
        }

        $strKey = (
            '{0}|{1}|{2}' -f
            [string]$objRow.PrincipalKey,
            [string]$objRow.OperationName,
            $strCorrelationId
        )

        if (-not $hashtableSeen.ContainsKey($strKey)) {
            $hashtableSeen[$strKey] = $true
            [void]($listOut.Add($objRow))
        }
    }

    return $listOut.ToArray()
}
#endregion Load dependencies

#region Ensure output directory exists
$strOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if (-not (Test-Path -LiteralPath $strOutputPath)) {
    [void]([System.IO.Directory]::CreateDirectory($strOutputPath))
}
#endregion Ensure output directory exists

#region Pre-flight writeability probe
# Per powershell.instructions.md "File Writeability Testing": verify the
# output directory is writable before running the benchmark iterations so a
# permissions or lock failure surfaces immediately instead of after the
# full measurement run completes.
$strWriteProbePath = [System.IO.Path]::Combine(
    $strOutputPath,
    ('.write_probe_{0}.tmp' -f [System.Guid]::NewGuid().ToString('N'))
)
try {
    $objWriteProbeStream = [System.IO.File]::Open(
        $strWriteProbePath,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    $objWriteProbeStream.Dispose()
    [System.IO.File]::Delete($strWriteProbePath)
} catch {
    throw ("Benchmark output directory '{0}' is not writable: {1}" -f $strOutputPath, $_.Exception.Message)
}
#endregion Pre-flight writeability probe

#region Run benchmark iterations
$listResults = New-Object System.Collections.Generic.List[pscustomobject]

foreach ($dblDupRatio in $DuplicateRatios) {
    for ($intIter = 1; $intIter -le $Iterations; $intIter++) {
        Write-Verbose ("Running: FixtureSize={0}, DuplicateRatio={1}, Iteration={2}/{3}" -f $FixtureSize, $dblDupRatio, $intIter, $Iterations)

        # Generate fixture
        $arrFixture = @(New-SyntheticAuditLogFixture -Count $FixtureSize -DuplicateRatio $dblDupRatio -Seed $Seed)

        # Mock Invoke-AzOperationalInsightsQuery to return the fixture.
        # The behaviour varies by -Mode:
        #   Legacy       -> return the full fixture to every chunk (no time
        #                   filter, no collapse). Preserves pre-existing
        #                   benchmark output byte-exactly.
        #   Baseline     -> filter by the chunk's KQL time window only (no
        #                   server-side collapse). Measures pre-Option-A
        #                   emitted row counts.
        #   OptionA      -> apply the Option A collapse once to the whole
        #                   fixture, then filter by the chunk's time window.
        #                   Approximates a single-query Option A path.
        #   OptionAPlusB -> filter by the chunk's time window, then apply
        #                   the Option A collapse per chunk. Matches the
        #                   current production KQL path.
        $script:arrBenchFixture = $arrFixture
        $script:arrBenchCollapsedGlobal = $null
        if ($Mode -eq 'OptionA') {
            $script:arrBenchCollapsedGlobal = @(Invoke-BenchOptionACollapse -Rows $arrFixture)
        }
        $script:strBenchMode = $Mode
        function Invoke-AzOperationalInsightsQuery {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSReviewUnusedParameter', '',
                Justification = 'Parameters exist to mirror the stubbed cmdlet signature.')]
            [CmdletBinding()]
            param ($WorkspaceId, $Query)
            switch ($script:strBenchMode) {
                'Legacy' {
                    return [pscustomobject]@{ Results = $script:arrBenchFixture }
                }
                'Baseline' {
                    $arrFiltered = @(Select-BenchRowByKqlTimeWindow -Query $Query -Rows $script:arrBenchFixture)
                    return [pscustomobject]@{ Results = $arrFiltered }
                }
                'OptionA' {
                    $arrFiltered = @(Select-BenchRowByKqlTimeWindow -Query $Query -Rows $script:arrBenchCollapsedGlobal)
                    return [pscustomobject]@{ Results = $arrFiltered }
                }
                'OptionAPlusB' {
                    $arrFiltered = @(Select-BenchRowByKqlTimeWindow -Query $Query -Rows $script:arrBenchFixture)
                    if ($arrFiltered.Count -eq 0) {
                        return [pscustomobject]@{ Results = @() }
                    }
                    $arrCollapsed = @(Invoke-BenchOptionACollapse -Rows $arrFiltered)
                    return [pscustomobject]@{ Results = $arrCollapsed }
                }
            }
        }

        # Time the stage-1 pipeline
        $objStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $hashtableUnmapped = @{}
        $arrEvents = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId 'bench-workspace' -Start ([datetime]'2025-12-01') -End ([datetime]'2026-01-16') -UnmappedActivityAccumulator $hashtableUnmapped)
        $arrDeduped = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)
        $hashtableDisplayNames = ConvertTo-PrincipalDisplayNameMap -Events $arrDeduped
        $arrCounts = @(ConvertTo-PrincipalActionCount -Events $arrDeduped)

        $objStopwatch.Stop()

        # Suppress unused variable warnings
        [void]$hashtableDisplayNames
        [void]$hashtableUnmapped

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
Write-Output "| DuplicateRatio | MedianWallClockMs | P95WallClockMs | MedianEventsEmitted | TriplesProduced |"
Write-Output "|---|---|---|---|---|"

foreach ($dblDupRatio in $DuplicateRatios) {
    $arrSubset = @($listResults | Where-Object { $_.DuplicateRatio -eq $dblDupRatio })
    if ($arrSubset.Count -eq 0) {
        continue
    }

    # Calculate statistical median (average of the two middle values for even
    # counts; middle value for odd counts) and P95 for wall clock.
    $arrWallClockSorted = @($arrSubset | Sort-Object StageOneWallClockMs | Select-Object -ExpandProperty StageOneWallClockMs)
    $intWallClockCount = $arrWallClockSorted.Count
    $intWallClockUpperMedianIndex = [Math]::Floor($intWallClockCount / 2)
    if (($intWallClockCount % 2) -eq 0) {
        $dblMedianWallClock = ($arrWallClockSorted[$intWallClockUpperMedianIndex - 1] + $arrWallClockSorted[$intWallClockUpperMedianIndex]) / 2.0
    } else {
        $dblMedianWallClock = $arrWallClockSorted[$intWallClockUpperMedianIndex]
    }

    $intP95Index = [Math]::Min([Math]::Ceiling($arrWallClockSorted.Count * 0.95) - 1, $arrWallClockSorted.Count - 1)
    $intP95WallClock = $arrWallClockSorted[$intP95Index]

    # Median events emitted from ingestion (the stage-1 input volume after
    # Get-EntraIdAuditEventFromLogAnalytics processes the mock fixture).
    $arrRowsSorted = @($arrSubset | Sort-Object EventsEmittedFromIngestion | Select-Object -ExpandProperty EventsEmittedFromIngestion)
    $intRowCount = $arrRowsSorted.Count
    $intRowsUpperMedianIndex = [Math]::Floor($intRowCount / 2)
    if (($intRowCount % 2) -eq 0) {
        $dblMedianEvents = ($arrRowsSorted[$intRowsUpperMedianIndex - 1] + $arrRowsSorted[$intRowsUpperMedianIndex]) / 2.0
    } else {
        $dblMedianEvents = $arrRowsSorted[$intRowsUpperMedianIndex]
    }

    # Take TriplesProduced from first iteration (deterministic, same across iterations)
    $intTriples = $arrSubset[0].TriplesAfterStageOne

    Write-Output ("| {0} | {1} | {2} | {3} | {4} |" -f $dblDupRatio, $dblMedianWallClock, $intP95WallClock, $dblMedianEvents, $intTriples)
}

Write-Output ""
Write-Output ("Label: {0}, FixtureSize: {1}, Iterations: {2}, Seed: {3}" -f $Label, $FixtureSize, $Iterations, $Seed)
#endregion Emit Markdown summary
