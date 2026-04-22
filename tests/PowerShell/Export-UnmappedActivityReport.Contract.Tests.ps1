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

    . (Join-Path -Path $strFixturesPath -ChildPath 'New-SyntheticAuditLogFixture.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-EntraIdResourceAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-EntraIdAuditEventFromLogAnalytics.ps1')

    function Export-UnmappedActivityReportForTest {
        # .SYNOPSIS
        # Writes entra_unmapped_activities.csv using the exact logic from
        # Invoke-RoleMiningPipeline.ps1.
        # .DESCRIPTION
        # Mirrors the CSV export block in Invoke-RoleMiningPipeline.ps1 so
        # this contract test exercises the same producer code path that
        # ships with the pipeline. Keeping the logic byte-identical is
        # important because OQ4 defines the CSV file (not the in-memory
        # accumulator) as the authoritative contract surface.
        # .PARAMETER Accumulator
        # Hashtable populated by ConvertFrom-EntraIdAuditRecord via the
        # -UnmappedActivityAccumulator parameter.
        # .PARAMETER Path
        # Absolute path where entra_unmapped_activities.csv will be
        # written.
        # .EXAMPLE
        # Export-UnmappedActivityReportForTest -Accumulator $hash -Path $strCsvPath
        # # Writes the CSV to the supplied path.
        # .INPUTS
        # None. You cannot pipe objects to this function.
        # .OUTPUTS
        # None. The function writes the CSV to disk as a side effect.
        # .NOTES
        # PRIVATE/INTERNAL HELPER -- This function is not part of the
        # public API surface. It exists solely to keep the contract test
        # focused on the CSV-on-disk invariants that OQ4 defines.
        #
        # Version: 1.0.20260422.2
        [CmdletBinding()]
        [OutputType([void])]
        param (
            [Parameter(Mandatory = $true)]
            [hashtable]$Accumulator,

            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$Path
        )

        $objUtf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
        $arrUnmappedSorted = @($Accumulator.Values |
                Sort-Object -Property Count -Descending)
        $arrUnmappedCsvLines = @($arrUnmappedSorted | ConvertTo-Csv -NoTypeInformation)
        [System.IO.File]::WriteAllLines($Path, [string[]]$arrUnmappedCsvLines, $objUtf8NoBomEncoding)
    }

    function Invoke-UnmappedAccumulatorBuild {
        # .SYNOPSIS
        # Builds the unmapped-activity accumulator from a synthetic
        # fixture.
        # .DESCRIPTION
        # Mocks Invoke-AzOperationalInsightsQuery with the supplied
        # fixture rows, then calls Get-EntraIdAuditEventFromLogAnalytics
        # with an -UnmappedActivityAccumulator hashtable. Returns the
        # populated hashtable.
        # .PARAMETER FixtureRows
        # Synthetic audit-log rows produced by New-SyntheticAuditLogFixture.
        # .OUTPUTS
        # [hashtable] The populated unmapped-activity accumulator.
        # .NOTES
        # PRIVATE/INTERNAL HELPER -- This function is not part of the
        # public API surface.
        #
        # Version: 1.0.20260422.0
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSReviewUnusedParameter', 'FixtureRows',
            Justification = 'FixtureRows is captured by the Mock closure and used when Pester invokes the mock.')]
        [CmdletBinding()]
        [OutputType([hashtable])]
        param (
            [Parameter(Mandatory = $true)]
            [object[]]$FixtureRows
        )

        Mock Invoke-AzOperationalInsightsQuery {
            [pscustomobject]@{ Results = $FixtureRows }
        }

        $hashtableUnmapped = @{}
        $null = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId 'test-workspace-id' -Start ([datetime]'2025-12-01') -End ([datetime]'2026-01-16') -UnmappedActivityAccumulator $hashtableUnmapped)
        return $hashtableUnmapped
    }
}


Describe "entra_unmapped_activities.csv contract (OQ4)" {
    # OQ4 resolution (issue #23): the entra_unmapped_activities.csv
    # contract is stable AND codified by a Pester contract test so the
    # schema and its invariants are enforced in CI rather than kept as
    # lore. This Describe block is the authoritative contract
    # definition for the unmapped-activity diagnostic artifact.

    BeforeAll {
        # Use the synthetic fixture with a non-zero UnmappedActivityRatio
        # so the accumulator is guaranteed to have content. The default
        # ratio is 0.1, which yields >= 1 unmapped activity for these
        # fixture sizes across all random seeds emitted by the generator.
        $script:arrFixture = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.25 -Seed 42)
        $script:hashtableUnmapped = Invoke-UnmappedAccumulatorBuild -FixtureRows $script:arrFixture

        # Preconditions for the contract tests below. If either of these
        # fail, the fixture has drifted in a way that invalidates the
        # test -- not the contract itself.
        $script:hashtableUnmapped.Count | Should -BeGreaterThan 0

        $script:strTempCsv = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('entra_unmapped_activities_{0}.csv' -f ([Guid]::NewGuid().ToString('N')))
        Export-UnmappedActivityReportForTest -Accumulator $script:hashtableUnmapped -Path $script:strTempCsv

        $script:strResolvedCsv = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($script:strTempCsv)
        Test-Path -LiteralPath $script:strResolvedCsv | Should -BeTrue

        $script:arrCsvLines = @([System.IO.File]::ReadAllLines($script:strResolvedCsv))
        $script:arrCsvRows = @(Import-Csv -LiteralPath $script:strResolvedCsv)
    }

    AfterAll {
        if ($null -ne $script:strResolvedCsv -and (Test-Path -LiteralPath $script:strResolvedCsv)) {
            Remove-Item -LiteralPath $script:strResolvedCsv -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Header" {
        It "First line of the CSV is exactly the five-column header in the contracted order" {
            # Arrange
            $strExpectedHeader = '"ActivityDisplayName","Category","Count","SampleCorrelationId","SampleRecordId"'

            # Assert
            $script:arrCsvLines | Should -Not -BeNullOrEmpty
            $script:arrCsvLines[0] | Should -BeExactly $strExpectedHeader
        }

        It "Parsed CSV exposes exactly the five contracted columns (set check; header-order contract asserted above)" {
            # The header-order contract is asserted byte-for-byte against
            # the raw CSV header line in the preceding It block. This
            # assertion is a set-membership check on the parsed object's
            # property names. Per the PowerShell instructions' "Testing
            # Property Names on PSCustomObject" rule, assertions on
            # PSObject.Properties.Name MUST be order-insensitive because
            # PSCustomObject property ordering is not a documented
            # guarantee even when hashtable literals preserve it in
            # practice.

            # Assert
            $script:arrCsvRows | Should -Not -BeNullOrEmpty
            $arrActualColumns = $script:arrCsvRows[0].PSObject.Properties.Name
            $arrActualColumns | Should -Contain 'ActivityDisplayName'
            $arrActualColumns | Should -Contain 'Category'
            $arrActualColumns | Should -Contain 'Count'
            $arrActualColumns | Should -Contain 'SampleCorrelationId'
            $arrActualColumns | Should -Contain 'SampleRecordId'
            $arrActualColumns | Should -HaveCount 5
        }
    }

    Context "Row invariants" {
        It "Every row has Count >= 1" {
            # Assert
            $script:arrCsvRows | Should -Not -BeNullOrEmpty
            foreach ($objRow in $script:arrCsvRows) {
                $intCount = 0
                $boolParsed = [int]::TryParse([string]$objRow.Count, [ref]$intCount)
                $boolParsed | Should -BeTrue
                $intCount | Should -BeGreaterOrEqual 1
            }
        }

        It "Every non-empty SampleCorrelationId parses via [Guid]::TryParse" {
            # Assert
            $script:arrCsvRows | Should -Not -BeNullOrEmpty
            foreach ($objRow in $script:arrCsvRows) {
                $strCorrelationId = [string]$objRow.SampleCorrelationId
                if (-not [string]::IsNullOrEmpty($strCorrelationId)) {
                    $guidParsed = [Guid]::Empty
                    $boolParsed = [Guid]::TryParse($strCorrelationId, [ref]$guidParsed)
                    $boolParsed | Should -BeTrue
                }
            }
        }

        It "Every SampleRecordId is non-empty when the source fixture has a RecordId for that activity/category group" {
            # Arrange / Assert
            $script:arrCsvRows | Should -Not -BeNullOrEmpty
            foreach ($objRow in $script:arrCsvRows) {
                $strActivity = [string]$objRow.ActivityDisplayName
                $strCategory = [string]$objRow.Category

                $arrGroup = @($script:arrFixture | Where-Object {
                        $_.OperationName -eq $strActivity -and $_.Category -eq $strCategory
                    })
                $arrGroupWithRecordId = @($arrGroup | Where-Object {
                        -not [string]::IsNullOrEmpty([string]$_.RecordId)
                    })

                if ($arrGroupWithRecordId.Count -gt 0) {
                    ([string]$objRow.SampleRecordId) | Should -Not -BeNullOrEmpty
                }
            }
        }
    }
}
