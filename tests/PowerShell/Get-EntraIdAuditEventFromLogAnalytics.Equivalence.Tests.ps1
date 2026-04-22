BeforeAll {
    # Stub function that mimics the real Az.OperationalInsights cmdlet so Pester
    # can Mock it without importing Az.OperationalInsights in CI.
    function Invoke-AzOperationalInsightsQuery {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSReviewUnusedParameter', '',
            Justification = 'Parameters exist to mirror the stubbed cmdlet signature so Pester Mocks bind correctly.')]
        [CmdletBinding()]
        param ($WorkspaceId, $Query)
    }

    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'
    $strFixturesPath = Join-Path -Path $PSScriptRoot -ChildPath '_fixtures'
    # $script: prefix allows PSScriptAnalyzer to recognize cross-scope usage in
    # Pester It blocks that reference this path.
    $script:strGoldenPath = Join-Path -Path $strFixturesPath -ChildPath 'golden'

    . (Join-Path -Path $strFixturesPath -ChildPath 'New-SyntheticAuditLogFixture.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-EntraIdResourceAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-EntraIdAuditEventFromLogAnalytics.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Remove-DuplicateCanonicalEvent.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-PrincipalDisplayNameMap.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-PrincipalActionCount.ps1')


    function Invoke-StageOnePipeline {
        # .SYNOPSIS
        # Runs the stage-1 pipeline segment on a synthetic fixture.
        # .DESCRIPTION
        # Generates a fixture, mocks Invoke-AzOperationalInsightsQuery,
        # runs Get-EntraIdAuditEventFromLogAnalytics through
        # Remove-DuplicateCanonicalEvent, ConvertTo-PrincipalDisplayNameMap,
        # and ConvertTo-PrincipalActionCount.
        # .PARAMETER FixtureRows
        # The synthetic fixture rows to use as mock results.
        # .OUTPUTS
        # [pscustomobject] with Triples, DisplayNameMap, UnmappedAccumulator,
        # and EventsEmitted properties.
        # .NOTES
        # PRIVATE/INTERNAL HELPER -- This function is not part of the
        # public API surface. Parameters, return shape, and positional
        # contract may change without notice.
        #
        # Version: 1.0.20260420.0
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSReviewUnusedParameter', 'FixtureRows',
            Justification = 'FixtureRows is captured by the Mock closure and used when Pester invokes the mock.')]
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param (
            [Parameter(Mandatory = $true)]
            [object[]]$FixtureRows
        )

        Mock Invoke-AzOperationalInsightsQuery {
            [pscustomobject]@{ Results = $FixtureRows }
        }

        $hashUnmapped = @{}
        $arrEvents = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId 'test-workspace-id' -Start ([datetime]'2025-12-01') -End ([datetime]'2026-01-16') -UnmappedActivityAccumulator $hashUnmapped)

        $arrDeduped = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)
        $hashDisplayNames = ConvertTo-PrincipalDisplayNameMap -Events $arrDeduped
        $arrCounts = @(ConvertTo-PrincipalActionCount -Events $arrDeduped)

        return [pscustomobject]@{
            Triples = $arrCounts
            DisplayNameMap = $hashDisplayNames
            UnmappedAccumulator = $hashUnmapped
            EventsEmitted = $arrEvents.Count
        }
    }


    function Invoke-OptionAServerSideCollapse {
        # .SYNOPSIS
        # Simulates the server-side Option A dedup collapse on raw
        # synthetic fixture rows.
        # .DESCRIPTION
        # Emulates the KQL pattern in Get-EntraIdAuditEventFromLogAnalytics:
        #
        #   let src =
        #       <projected rows>
        #       | extend CorrelationIdNormalized = trim(@"\s+", tostring(CorrelationId))
        #       | project ..., CorrelationId, CorrelationIdNormalized, ...;
        #   src
        #   | where isnotempty(CorrelationIdNormalized)
        #   | summarize arg_min(TimeGenerated, Category, PrincipalType,
        #                       PrincipalUPN, AppId, RecordId)
        #       by PrincipalKey, OperationName, CorrelationIdNormalized
        #   | project-rename CorrelationId = CorrelationIdNormalized
        #   | union (src | where isempty(CorrelationIdNormalized))
        #
        # Rows whose CorrelationId is not null, empty, or whitespace-only
        # are grouped by the composite key
        # (PrincipalKey, OperationName, CorrelationId) and reduced to
        # the single row with the earliest TimeGenerated per group.
        # Rows whose CorrelationId IS null, empty, or whitespace-only
        # are preserved unchanged, matching REQ-DED-001 and
        # Remove-DuplicateCanonicalEvent's [string]::IsNullOrWhiteSpace
        # contract. The output shape matches New-SyntheticAuditLogFixture
        # so the result can be handed straight to Invoke-StageOnePipeline
        # as a mock result.
        # .PARAMETER FixtureRows
        # The raw (pre-aggregation) fixture rows to collapse.
        # .EXAMPLE
        # $arrRaw = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.25 -Seed 42)
        # $arrCollapsed = @(Invoke-OptionAServerSideCollapse -FixtureRows $arrRaw)
        # # # $arrCollapsed contains the same rows as $arrRaw, except that
        # # # retry duplicates sharing (PrincipalKey, OperationName,
        # # # CorrelationId) have been collapsed to the single row with
        # # # the earliest TimeGenerated per group.
        # .INPUTS
        # None. You cannot pipe objects to this function.
        # .OUTPUTS
        # [pscustomobject] Collapsed fixture rows streamed to the
        # pipeline.
        # .NOTES
        # PRIVATE/INTERNAL HELPER -- This function is not part of the
        # public API surface. Parameters, return shape, and positional
        # contract may change without notice.
        #
        # Version: 1.1.20260422.0
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param (
            [Parameter(Mandatory = $true)]
            [object[]]$FixtureRows
        )

        $hashtableSeen = @{}

        # Stable sort by TimeGenerated so arg_min semantics are
        # preserved: the first row seen per composite key is the one
        # with the earliest TimeGenerated.
        $arrSorted = @($FixtureRows | Sort-Object TimeGenerated)

        foreach ($objRow in $arrSorted) {
            $strCorrelationId = ''
            if ($null -ne $objRow.CorrelationId) {
                $strCorrelationId = [string]$objRow.CorrelationId
            }

            if ([string]::IsNullOrWhiteSpace($strCorrelationId)) {
                # Missing-CorrelationId branch (null / empty /
                # whitespace-only): preserved unchanged via the KQL
                # union, matching Remove-DuplicateCanonicalEvent's
                # [string]::IsNullOrWhiteSpace contract.
                $objRow
                continue
            }

            $strKey = ('{0}|{1}|{2}' -f `
                    [string]$objRow.PrincipalKey, `
                    [string]$objRow.OperationName, `
                    $strCorrelationId)

            if (-not $hashtableSeen.ContainsKey($strKey)) {
                $hashtableSeen[$strKey] = $true
                $objRow
            }
        }
    }


    function ConvertTo-SortedGoldenJson {
        # .SYNOPSIS
        # Converts stage-1 outputs to deterministic JSON for golden files.
        # .DESCRIPTION
        # Produces sorted JSON suitable for deterministic diffs.
        # Triples are sorted by PrincipalKey then Action.
        # DisplayNameMap is converted to sorted key-value pairs.
        # UnmappedAccumulator is converted to sorted entries.
        # .PARAMETER StageOneResult
        # The output of Invoke-StageOnePipeline.
        # .PARAMETER OutputKind
        # Which output to serialize: 'Triples', 'DisplayNameMap', or
        # 'UnmappedAccumulator'.
        # .OUTPUTS
        # [string] JSON string.
        # .NOTES
        # PRIVATE/INTERNAL HELPER -- This function is not part of the
        # public API surface. Parameters, return shape, and positional
        # contract may change without notice.
        #
        # Version: 1.0.20260420.0
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory = $true)]
            [pscustomobject]$StageOneResult,

            [Parameter(Mandatory = $true)]
            [ValidateSet('Triples', 'DisplayNameMap', 'UnmappedAccumulator')]
            [string]$OutputKind
        )

        # Append a trailing LF so on-disk golden files end with a final newline
        # (required by the repo-wide end-of-file-fixer pre-commit hook) and so
        # regenerated output compares byte-identical against those files.
        #
        # Windows PowerShell's ConvertTo-Json emits CRLF between lines. The
        # committed goldens are pinned to LF via .gitattributes so byte-exact
        # comparisons are stable across platforms; normalize the generated
        # JSON to LF here so Windows runs match the on-disk goldens.
        #
        # Each kind collects its entries with @(foreach { ... }) instead of
        # $arr += [ordered]@{...} inside a loop to avoid the O(n^2) array-copy
        # cost of repeated += on large golden regenerations.
        switch ($OutputKind) {
            'Triples' {
                $arrSorted = @($StageOneResult.Triples | Sort-Object PrincipalKey, Action)
                $arrForJson = @(
                    foreach ($objTriple in $arrSorted) {
                        [ordered]@{
                            Action = $objTriple.Action
                            Count = $objTriple.Count
                            PrincipalKey = $objTriple.PrincipalKey
                        }
                    }
                )
                return (((ConvertTo-Json -InputObject $arrForJson -Depth 5) -replace "`r`n", "`n") + "`n")
            }
            'DisplayNameMap' {
                # Emit fields in alphabetical order (DisplayName before
                # PrincipalKey) so the JSON field order matches the repo
                # determinism convention that Triples and
                # UnmappedAccumulator already follow.
                $arrSorted = @(
                    foreach ($strKey in ($StageOneResult.DisplayNameMap.Keys | Sort-Object)) {
                        [ordered]@{
                            DisplayName = $StageOneResult.DisplayNameMap[$strKey]
                            PrincipalKey = $strKey
                        }
                    }
                )
                return (((ConvertTo-Json -InputObject $arrSorted -Depth 5) -replace "`r`n", "`n") + "`n")
            }
            'UnmappedAccumulator' {
                $arrSorted = @(
                    foreach ($strKey in ($StageOneResult.UnmappedAccumulator.Keys | Sort-Object)) {
                        $objEntry = $StageOneResult.UnmappedAccumulator[$strKey]
                        [ordered]@{
                            ActivityDisplayName = $objEntry.ActivityDisplayName
                            Category = $objEntry.Category
                            Count = $objEntry.Count
                            SampleCorrelationId = $objEntry.SampleCorrelationId
                            SampleRecordId = $objEntry.SampleRecordId
                        }
                    }
                )
                return (((ConvertTo-Json -InputObject $arrSorted -Depth 5) -replace "`r`n", "`n") + "`n")
            }
        }
    }


    function Test-StageOneEquivalence {
        # .SYNOPSIS
        # Compares two stage-1 output sets for equivalence.
        # .DESCRIPTION
        # Checks that Triples, DisplayNameMap, and UnmappedAccumulator
        # from two pipeline runs match according to the equivalence
        # contract defined in the issue specification.
        #
        # - Sparse triples: strict set equality (sorted by PrincipalKey,
        #   Action).
        # - Display-name map: strict equality.
        # - Unmapped accumulator counts + activity names: strict equality.
        # - Unmapped accumulator SampleCorrelationId / SampleRecordId:
        #   valid-sample check (the sample ID must exist in the original
        #   fixture rows for that activity/category group).
        # .PARAMETER Expected
        # The expected (golden) stage-1 result.
        # .PARAMETER Actual
        # The actual stage-1 result to compare.
        # .PARAMETER FixtureRows
        # The original fixture rows used to generate the actual result.
        # Needed for valid-sample checks on unmapped accumulator entries.
        # .OUTPUTS
        # [pscustomobject] with Pass (bool) and Details (string[])
        # properties.
        # .NOTES
        # PRIVATE/INTERNAL HELPER -- This function is not part of the
        # public API surface. Parameters, return shape, and positional
        # contract may change without notice.
        #
        # Version: 1.0.20260420.0
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param (
            [Parameter(Mandatory = $true)]
            [pscustomobject]$Expected,

            [Parameter(Mandatory = $true)]
            [pscustomobject]$Actual,

            [object[]]$FixtureRows
        )

        $boolPass = $true
        $arrDetails = New-Object System.Collections.Generic.List[string]

        # 1. Compare Triples (strict set equality)
        $arrExpTriples = @($Expected.Triples | Sort-Object PrincipalKey, Action)
        $arrActTriples = @($Actual.Triples | Sort-Object PrincipalKey, Action)

        if ($arrExpTriples.Count -ne $arrActTriples.Count) {
            $boolPass = $false
            [void]($arrDetails.Add(('Triples count mismatch: expected {0}, got {1}' -f $arrExpTriples.Count, $arrActTriples.Count)))
        } else {
            for ($i = 0; $i -lt $arrExpTriples.Count; $i++) {
                if ($arrExpTriples[$i].PrincipalKey -ne $arrActTriples[$i].PrincipalKey -or
                    $arrExpTriples[$i].Action -ne $arrActTriples[$i].Action -or
                    $arrExpTriples[$i].Count -ne $arrActTriples[$i].Count) {
                    $boolPass = $false
                    [void]($arrDetails.Add(('Triple mismatch at index {0}' -f $i)))
                }
            }
        }

        # 2. Compare DisplayNameMap (strict equality)
        $arrExpKeys = @($Expected.DisplayNameMap.Keys | Sort-Object)
        $arrActKeys = @($Actual.DisplayNameMap.Keys | Sort-Object)

        if ($arrExpKeys.Count -ne $arrActKeys.Count) {
            $boolPass = $false
            [void]($arrDetails.Add(('DisplayNameMap key count mismatch: expected {0}, got {1}' -f $arrExpKeys.Count, $arrActKeys.Count)))
        } else {
            for ($i = 0; $i -lt $arrExpKeys.Count; $i++) {
                if ($arrExpKeys[$i] -ne $arrActKeys[$i]) {
                    $boolPass = $false
                    [void]($arrDetails.Add(('DisplayNameMap key mismatch at index {0}' -f $i)))
                } elseif ($Expected.DisplayNameMap[$arrExpKeys[$i]] -ne $Actual.DisplayNameMap[$arrActKeys[$i]]) {
                    $boolPass = $false
                    [void]($arrDetails.Add(('DisplayNameMap value mismatch for key {0}' -f $arrExpKeys[$i])))
                }
            }
        }

        # 3. Compare UnmappedAccumulator counts + activity names (strict equality)
        $arrExpUnmappedKeys = @($Expected.UnmappedAccumulator.Keys | Sort-Object)
        $arrActUnmappedKeys = @($Actual.UnmappedAccumulator.Keys | Sort-Object)

        if ($arrExpUnmappedKeys.Count -ne $arrActUnmappedKeys.Count) {
            $boolPass = $false
            [void]($arrDetails.Add(('UnmappedAccumulator key count mismatch: expected {0}, got {1}' -f $arrExpUnmappedKeys.Count, $arrActUnmappedKeys.Count)))
        } else {
            for ($i = 0; $i -lt $arrExpUnmappedKeys.Count; $i++) {
                if ($arrExpUnmappedKeys[$i] -ne $arrActUnmappedKeys[$i]) {
                    $boolPass = $false
                    [void]($arrDetails.Add(('UnmappedAccumulator key mismatch at index {0}' -f $i)))
                    continue
                }
                $strKey = $arrExpUnmappedKeys[$i]
                $objExp = $Expected.UnmappedAccumulator[$strKey]
                $objAct = $Actual.UnmappedAccumulator[$strKey]

                if ($objExp.ActivityDisplayName -ne $objAct.ActivityDisplayName) {
                    $boolPass = $false
                    [void]($arrDetails.Add(('UnmappedAccumulator ActivityDisplayName mismatch for key {0}' -f $strKey)))
                }
                if ($objExp.Category -ne $objAct.Category) {
                    $boolPass = $false
                    [void]($arrDetails.Add(('UnmappedAccumulator Category mismatch for key {0}' -f $strKey)))
                }
                if ($objExp.Count -ne $objAct.Count) {
                    $boolPass = $false
                    [void]($arrDetails.Add(('UnmappedAccumulator Count mismatch for key {0}: expected {1}, got {2}' -f $strKey, $objExp.Count, $objAct.Count)))
                }

                # Valid-sample check for SampleCorrelationId / SampleRecordId
                if ($null -ne $FixtureRows -and $FixtureRows.Count -gt 0) {
                    $strActivity = $objAct.ActivityDisplayName
                    $strCategory = $objAct.Category
                    $arrMatchingRows = @($FixtureRows | Where-Object {
                            $_.OperationName -eq $strActivity -and $_.Category -eq $strCategory
                        })

                    if (-not [string]::IsNullOrEmpty($objAct.SampleCorrelationId)) {
                        $arrMatchingCorr = @($arrMatchingRows | Where-Object { $_.CorrelationId -eq $objAct.SampleCorrelationId })
                        if ($arrMatchingCorr.Count -eq 0) {
                            $boolPass = $false
                            [void]($arrDetails.Add(('UnmappedAccumulator SampleCorrelationId "{0}" for key {1} not found in fixture rows' -f $objAct.SampleCorrelationId, $strKey)))
                        }
                    }
                    if (-not [string]::IsNullOrEmpty($objAct.SampleRecordId)) {
                        $arrMatchingRec = @($arrMatchingRows | Where-Object { $_.RecordId -eq $objAct.SampleRecordId })
                        if ($arrMatchingRec.Count -eq 0) {
                            $boolPass = $false
                            [void]($arrDetails.Add(('UnmappedAccumulator SampleRecordId "{0}" for key {1} not found in fixture rows' -f $objAct.SampleRecordId, $strKey)))
                        }
                    }
                }
            }
        }

        return [pscustomobject]@{
            Pass = $boolPass
            Details = $arrDetails.ToArray()
        }
    }
}


Describe "Get-EntraIdAuditEventFromLogAnalytics Equivalence" {
    Context "Golden file regeneration" -Tag 'Golden' {
        It "Regenerates goldens for DuplicateRatio 0.0" {
            # Arrange
            $arrFixture = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.0 -Seed 42)
            $objResult = Invoke-StageOnePipeline -FixtureRows $arrFixture

            # Act - write golden files
            $strTriplesJson = ConvertTo-SortedGoldenJson -StageOneResult $objResult -OutputKind 'Triples'
            $strDisplayNameJson = ConvertTo-SortedGoldenJson -StageOneResult $objResult -OutputKind 'DisplayNameMap'
            $strUnmappedJson = ConvertTo-SortedGoldenJson -StageOneResult $objResult -OutputKind 'UnmappedAccumulator'

            $objUtf8NoBom = New-Object System.Text.UTF8Encoding($false)
            $strTriplesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.0-triples.json'))
            $strDisplayNameFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.0-displaynames.json'))
            $strUnmappedFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.0-unmapped.json'))
            [System.IO.File]::WriteAllText($strTriplesFile, $strTriplesJson, $objUtf8NoBom)
            [System.IO.File]::WriteAllText($strDisplayNameFile, $strDisplayNameJson, $objUtf8NoBom)
            [System.IO.File]::WriteAllText($strUnmappedFile, $strUnmappedJson, $objUtf8NoBom)

            # Assert - files were written
            Test-Path -LiteralPath (Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.0-triples.json') | Should -BeTrue
        }

        It "Regenerates goldens for DuplicateRatio 0.25" {
            # Arrange
            $arrFixture = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.25 -Seed 42)
            $objResult = Invoke-StageOnePipeline -FixtureRows $arrFixture

            # Act - write golden files
            $strTriplesJson = ConvertTo-SortedGoldenJson -StageOneResult $objResult -OutputKind 'Triples'
            $strDisplayNameJson = ConvertTo-SortedGoldenJson -StageOneResult $objResult -OutputKind 'DisplayNameMap'
            $strUnmappedJson = ConvertTo-SortedGoldenJson -StageOneResult $objResult -OutputKind 'UnmappedAccumulator'

            $objUtf8NoBom = New-Object System.Text.UTF8Encoding($false)
            $strTriplesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.25-triples.json'))
            $strDisplayNameFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.25-displaynames.json'))
            $strUnmappedFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.25-unmapped.json'))
            [System.IO.File]::WriteAllText($strTriplesFile, $strTriplesJson, $objUtf8NoBom)
            [System.IO.File]::WriteAllText($strDisplayNameFile, $strDisplayNameJson, $objUtf8NoBom)
            [System.IO.File]::WriteAllText($strUnmappedFile, $strUnmappedJson, $objUtf8NoBom)

            # Assert - files were written
            Test-Path -LiteralPath (Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.25-triples.json') | Should -BeTrue
        }

        It "Regenerates goldens for DuplicateRatio 0.5" {
            # Arrange
            $arrFixture = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.5 -Seed 42)
            $objResult = Invoke-StageOnePipeline -FixtureRows $arrFixture

            # Act - write golden files
            $strTriplesJson = ConvertTo-SortedGoldenJson -StageOneResult $objResult -OutputKind 'Triples'
            $strDisplayNameJson = ConvertTo-SortedGoldenJson -StageOneResult $objResult -OutputKind 'DisplayNameMap'
            $strUnmappedJson = ConvertTo-SortedGoldenJson -StageOneResult $objResult -OutputKind 'UnmappedAccumulator'

            $objUtf8NoBom = New-Object System.Text.UTF8Encoding($false)
            $strTriplesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.5-triples.json'))
            $strDisplayNameFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.5-displaynames.json'))
            $strUnmappedFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.5-unmapped.json'))
            [System.IO.File]::WriteAllText($strTriplesFile, $strTriplesJson, $objUtf8NoBom)
            [System.IO.File]::WriteAllText($strDisplayNameFile, $strDisplayNameJson, $objUtf8NoBom)
            [System.IO.File]::WriteAllText($strUnmappedFile, $strUnmappedJson, $objUtf8NoBom)

            # Assert - files were written
            Test-Path -LiteralPath (Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.5-triples.json') | Should -BeTrue
        }
    }

    Context "Equivalence comparison against goldens for DuplicateRatio 0.0" {
        BeforeAll {
            $script:arrFixture00 = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.0 -Seed 42)
            $script:objResult00 = Invoke-StageOnePipeline -FixtureRows $script:arrFixture00
        }

        It "Triples match golden baseline" {
            # Arrange
            $strGoldenFile = Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.0-triples.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult00 -OutputKind 'Triples'
            $strExpectedJson = [System.IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($strGoldenFile))

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }

        It "DisplayNameMap matches golden baseline" {
            # Arrange
            $strGoldenFile = Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.0-displaynames.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult00 -OutputKind 'DisplayNameMap'
            $strExpectedJson = [System.IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($strGoldenFile))

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }

        It "UnmappedAccumulator matches golden baseline (counts and activity names)" {
            # Arrange
            $strGoldenFile = Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.0-unmapped.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult00 -OutputKind 'UnmappedAccumulator'
            $strExpectedJson = [System.IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($strGoldenFile))

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }
    }

    Context "Equivalence comparison against goldens for DuplicateRatio 0.25" {
        BeforeAll {
            $script:arrFixture025 = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.25 -Seed 42)
            $script:objResult025 = Invoke-StageOnePipeline -FixtureRows $script:arrFixture025
        }

        It "Triples match golden baseline" {
            # Arrange
            $strGoldenFile = Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.25-triples.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult025 -OutputKind 'Triples'
            $strExpectedJson = [System.IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($strGoldenFile))

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }

        It "DisplayNameMap matches golden baseline" {
            # Arrange
            $strGoldenFile = Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.25-displaynames.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult025 -OutputKind 'DisplayNameMap'
            $strExpectedJson = [System.IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($strGoldenFile))

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }

        It "UnmappedAccumulator matches golden baseline (counts and activity names)" {
            # Arrange
            $strGoldenFile = Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.25-unmapped.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult025 -OutputKind 'UnmappedAccumulator'
            $strExpectedJson = [System.IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($strGoldenFile))

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }
    }

    Context "Equivalence comparison against goldens for DuplicateRatio 0.5" {
        BeforeAll {
            $script:arrFixture05 = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.5 -Seed 42)
            $script:objResult05 = Invoke-StageOnePipeline -FixtureRows $script:arrFixture05
        }

        It "Triples match golden baseline" {
            # Arrange
            $strGoldenFile = Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.5-triples.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult05 -OutputKind 'Triples'
            $strExpectedJson = [System.IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($strGoldenFile))

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }

        It "DisplayNameMap matches golden baseline" {
            # Arrange
            $strGoldenFile = Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.5-displaynames.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult05 -OutputKind 'DisplayNameMap'
            $strExpectedJson = [System.IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($strGoldenFile))

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }

        It "UnmappedAccumulator matches golden baseline (counts and activity names)" {
            # Arrange
            $strGoldenFile = Join-Path -Path $script:strGoldenPath -ChildPath 'dup0.5-unmapped.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult05 -OutputKind 'UnmappedAccumulator'
            $strExpectedJson = [System.IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($strGoldenFile))

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }
    }

    Context "Test-StageOneEquivalence helper" {
        It "Returns Pass when outputs are identical" {
            # Arrange
            $arrFixture = @(New-SyntheticAuditLogFixture -Count 100 -DuplicateRatio 0.25 -Seed 42)
            $objResult1 = Invoke-StageOnePipeline -FixtureRows $arrFixture
            $objResult2 = Invoke-StageOnePipeline -FixtureRows $arrFixture

            # Act
            $objEquiv = Test-StageOneEquivalence -Expected $objResult1 -Actual $objResult2 -FixtureRows $arrFixture

            # Assert
            $objEquiv.Pass | Should -BeTrue
            $objEquiv.Details.Count | Should -Be 0
        }
    }

    Context "OQ1 row-count gate (Option A server-side collapse)" {
        # Per issue 23 OQ1: after Option A, the stage-1 event count for
        # the locked fixture (Count=10000, Seed=42) must be at most
        # (1 - DuplicateRatio + 0.10) x baseline. The baseline JSON
        # (committed by Phase 1) records the pre-collapse emitted event
        # count for each ratio in {0.0, 0.25, 0.5}; these values are
        # valid only for the exact fixture parameters locked by
        # Phase 1 (Count=10000, Seed=42, all other
        # New-SyntheticAuditLogFixture parameters at defaults).
        BeforeAll {
            $script:strBaselinePath = Join-Path -Path (Join-Path -Path $strFixturesPath -ChildPath 'baselines') -ChildPath 'row-count-baseline.json'
            Test-Path -LiteralPath $script:strBaselinePath | Should -BeTrue
            $strBaselineJson = [System.IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($script:strBaselinePath))
            $script:objBaseline = $strBaselineJson | ConvertFrom-Json

            # Fixture parameter lock assertion: the committed baseline
            # JSON is only valid for Count=10000 and Seed=42. If these
            # ever drift, stop -- regenerate Phase 1's baseline first.
            $script:objBaseline.fixtureCount | Should -Be 10000
            $script:objBaseline.seed | Should -Be 42
        }

        It "DuplicateRatio 0.0: emitted events <= (1 - 0.0 + 0.10) * baseline" {
            # Arrange
            $dblRatio = 0.0
            $intBaseline = [int]$script:objBaseline.ratios.'0.0'
            $intGate = [int][Math]::Floor((1.0 - $dblRatio + 0.10) * $intBaseline)

            $arrRaw = @(New-SyntheticAuditLogFixture -Count 10000 -DuplicateRatio $dblRatio -Seed 42)
            $arrCollapsed = @(Invoke-OptionAServerSideCollapse -FixtureRows $arrRaw)

            # Act
            $objResult = Invoke-StageOnePipeline -FixtureRows $arrCollapsed

            # Assert
            $objResult.EventsEmitted | Should -BeLessOrEqual $intGate
        }

        It "DuplicateRatio 0.25: emitted events <= (1 - 0.25 + 0.10) * baseline" {
            # Arrange
            $dblRatio = 0.25
            $intBaseline = [int]$script:objBaseline.ratios.'0.25'
            $intGate = [int][Math]::Floor((1.0 - $dblRatio + 0.10) * $intBaseline)

            $arrRaw = @(New-SyntheticAuditLogFixture -Count 10000 -DuplicateRatio $dblRatio -Seed 42)
            $arrCollapsed = @(Invoke-OptionAServerSideCollapse -FixtureRows $arrRaw)

            # Act
            $objResult = Invoke-StageOnePipeline -FixtureRows $arrCollapsed

            # Assert
            $objResult.EventsEmitted | Should -BeLessOrEqual $intGate
        }

        It "DuplicateRatio 0.5: emitted events <= (1 - 0.5 + 0.10) * baseline" {
            # Arrange
            $dblRatio = 0.5
            $intBaseline = [int]$script:objBaseline.ratios.'0.5'
            $intGate = [int][Math]::Floor((1.0 - $dblRatio + 0.10) * $intBaseline)

            $arrRaw = @(New-SyntheticAuditLogFixture -Count 10000 -DuplicateRatio $dblRatio -Seed 42)
            $arrCollapsed = @(Invoke-OptionAServerSideCollapse -FixtureRows $arrRaw)

            # Act
            $objResult = Invoke-StageOnePipeline -FixtureRows $arrCollapsed

            # Assert
            $objResult.EventsEmitted | Should -BeLessOrEqual $intGate
        }
    }

    Context "OQ2 equivalence: Option A collapsed vs. raw pipeline output" {
        # Per issue 23 OQ2: for DuplicateRatio 0.0 there are no retry
        # duplicates, so the Option A collapse is a no-op and the
        # collapsed-path output must be strictly identical to the
        # raw-path output. This test pins the simulator so that any
        # drift between the KQL pattern and
        # Invoke-OptionAServerSideCollapse surfaces here instead of
        # leaking into the row-count gate.
        #
        # For DuplicateRatio > 0.0 strict equivalence does not hold
        # under Test-StageOneEquivalence because that helper compares
        # UnmappedAccumulator Count by strict equality; Option A
        # collapses retry duplicates of unmapped activities
        # server-side, which reduces the post-collapse Count relative
        # to the raw path. That is the intended, correct behaviour and
        # is already covered by the OQ1 row-count gate above, so no
        # additional equivalence assertion is added here for higher
        # ratios.
        It "DuplicateRatio 0.0: collapsed output is strictly equivalent to raw output" {
            # Arrange
            $arrRaw = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.0 -Seed 42)
            $arrCollapsed = @(Invoke-OptionAServerSideCollapse -FixtureRows $arrRaw)

            $objRawResult = Invoke-StageOnePipeline -FixtureRows $arrRaw
            $objCollapsedResult = Invoke-StageOnePipeline -FixtureRows $arrCollapsed

            # Act
            $objEquiv = Test-StageOneEquivalence -Expected $objRawResult -Actual $objCollapsedResult -FixtureRows $arrRaw

            # Assert
            $objEquiv.Pass | Should -BeTrue
            $objEquiv.Details.Count | Should -Be 0
        }
    }
}
