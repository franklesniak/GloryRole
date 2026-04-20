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
    $strGoldenPath = Join-Path -Path $strFixturesPath -ChildPath 'golden'

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

        switch ($OutputKind) {
            'Triples' {
                $arrSorted = @($StageOneResult.Triples | Sort-Object PrincipalKey, Action)
                $arrForJson = @()
                foreach ($objTriple in $arrSorted) {
                    $arrForJson += [ordered]@{
                        Action = $objTriple.Action
                        Count = $objTriple.Count
                        PrincipalKey = $objTriple.PrincipalKey
                    }
                }
                return (ConvertTo-Json -InputObject $arrForJson -Depth 5)
            }
            'DisplayNameMap' {
                $arrSorted = @()
                foreach ($strKey in ($StageOneResult.DisplayNameMap.Keys | Sort-Object)) {
                    $arrSorted += [ordered]@{
                        PrincipalKey = $strKey
                        DisplayName = $StageOneResult.DisplayNameMap[$strKey]
                    }
                }
                return (ConvertTo-Json -InputObject $arrSorted -Depth 5)
            }
            'UnmappedAccumulator' {
                $arrSorted = @()
                foreach ($strKey in ($StageOneResult.UnmappedAccumulator.Keys | Sort-Object)) {
                    $objEntry = $StageOneResult.UnmappedAccumulator[$strKey]
                    $arrSorted += [ordered]@{
                        ActivityDisplayName = $objEntry.ActivityDisplayName
                        Category = $objEntry.Category
                        Count = $objEntry.Count
                        SampleCorrelationId = $objEntry.SampleCorrelationId
                        SampleRecordId = $objEntry.SampleRecordId
                    }
                }
                return (ConvertTo-Json -InputObject $arrSorted -Depth 5)
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
            [System.IO.File]::WriteAllText((Join-Path -Path $strGoldenPath -ChildPath 'dup0.0-triples.json'), $strTriplesJson, $objUtf8NoBom)
            [System.IO.File]::WriteAllText((Join-Path -Path $strGoldenPath -ChildPath 'dup0.0-displaynames.json'), $strDisplayNameJson, $objUtf8NoBom)
            [System.IO.File]::WriteAllText((Join-Path -Path $strGoldenPath -ChildPath 'dup0.0-unmapped.json'), $strUnmappedJson, $objUtf8NoBom)

            # Assert - files were written
            Test-Path -LiteralPath (Join-Path -Path $strGoldenPath -ChildPath 'dup0.0-triples.json') | Should -BeTrue
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
            [System.IO.File]::WriteAllText((Join-Path -Path $strGoldenPath -ChildPath 'dup0.25-triples.json'), $strTriplesJson, $objUtf8NoBom)
            [System.IO.File]::WriteAllText((Join-Path -Path $strGoldenPath -ChildPath 'dup0.25-displaynames.json'), $strDisplayNameJson, $objUtf8NoBom)
            [System.IO.File]::WriteAllText((Join-Path -Path $strGoldenPath -ChildPath 'dup0.25-unmapped.json'), $strUnmappedJson, $objUtf8NoBom)

            # Assert - files were written
            Test-Path -LiteralPath (Join-Path -Path $strGoldenPath -ChildPath 'dup0.25-triples.json') | Should -BeTrue
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
            [System.IO.File]::WriteAllText((Join-Path -Path $strGoldenPath -ChildPath 'dup0.5-triples.json'), $strTriplesJson, $objUtf8NoBom)
            [System.IO.File]::WriteAllText((Join-Path -Path $strGoldenPath -ChildPath 'dup0.5-displaynames.json'), $strDisplayNameJson, $objUtf8NoBom)
            [System.IO.File]::WriteAllText((Join-Path -Path $strGoldenPath -ChildPath 'dup0.5-unmapped.json'), $strUnmappedJson, $objUtf8NoBom)

            # Assert - files were written
            Test-Path -LiteralPath (Join-Path -Path $strGoldenPath -ChildPath 'dup0.5-triples.json') | Should -BeTrue
        }
    }

    Context "Equivalence comparison against goldens for DuplicateRatio 0.0" {
        BeforeAll {
            $script:arrFixture00 = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.0 -Seed 42)
            $script:objResult00 = Invoke-StageOnePipeline -FixtureRows $script:arrFixture00
        }

        It "Triples match golden baseline" {
            # Arrange
            $strGoldenFile = Join-Path -Path $strGoldenPath -ChildPath 'dup0.0-triples.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult00 -OutputKind 'Triples'
            $strExpectedJson = [System.IO.File]::ReadAllText($strGoldenFile)

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }

        It "DisplayNameMap matches golden baseline" {
            # Arrange
            $strGoldenFile = Join-Path -Path $strGoldenPath -ChildPath 'dup0.0-displaynames.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult00 -OutputKind 'DisplayNameMap'
            $strExpectedJson = [System.IO.File]::ReadAllText($strGoldenFile)

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }

        It "UnmappedAccumulator matches golden baseline (counts and activity names)" {
            # Arrange
            $strGoldenFile = Join-Path -Path $strGoldenPath -ChildPath 'dup0.0-unmapped.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult00 -OutputKind 'UnmappedAccumulator'
            $strExpectedJson = [System.IO.File]::ReadAllText($strGoldenFile)

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
            $strGoldenFile = Join-Path -Path $strGoldenPath -ChildPath 'dup0.25-triples.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult025 -OutputKind 'Triples'
            $strExpectedJson = [System.IO.File]::ReadAllText($strGoldenFile)

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }

        It "DisplayNameMap matches golden baseline" {
            # Arrange
            $strGoldenFile = Join-Path -Path $strGoldenPath -ChildPath 'dup0.25-displaynames.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult025 -OutputKind 'DisplayNameMap'
            $strExpectedJson = [System.IO.File]::ReadAllText($strGoldenFile)

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }

        It "UnmappedAccumulator matches golden baseline (counts and activity names)" {
            # Arrange
            $strGoldenFile = Join-Path -Path $strGoldenPath -ChildPath 'dup0.25-unmapped.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult025 -OutputKind 'UnmappedAccumulator'
            $strExpectedJson = [System.IO.File]::ReadAllText($strGoldenFile)

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
            $strGoldenFile = Join-Path -Path $strGoldenPath -ChildPath 'dup0.5-triples.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult05 -OutputKind 'Triples'
            $strExpectedJson = [System.IO.File]::ReadAllText($strGoldenFile)

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }

        It "DisplayNameMap matches golden baseline" {
            # Arrange
            $strGoldenFile = Join-Path -Path $strGoldenPath -ChildPath 'dup0.5-displaynames.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult05 -OutputKind 'DisplayNameMap'
            $strExpectedJson = [System.IO.File]::ReadAllText($strGoldenFile)

            # Assert
            $strActualJson | Should -Be $strExpectedJson
        }

        It "UnmappedAccumulator matches golden baseline (counts and activity names)" {
            # Arrange
            $strGoldenFile = Join-Path -Path $strGoldenPath -ChildPath 'dup0.5-unmapped.json'
            Test-Path -LiteralPath $strGoldenFile | Should -BeTrue

            # Act
            $strActualJson = ConvertTo-SortedGoldenJson -StageOneResult $script:objResult05 -OutputKind 'UnmappedAccumulator'
            $strExpectedJson = [System.IO.File]::ReadAllText($strGoldenFile)

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
}
