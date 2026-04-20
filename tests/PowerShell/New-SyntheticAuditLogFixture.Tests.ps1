BeforeAll {
    $strFixturesPath = Join-Path -Path $PSScriptRoot -ChildPath '_fixtures'
    . (Join-Path -Path $strFixturesPath -ChildPath 'New-SyntheticAuditLogFixture.ps1')

    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-EntraIdResourceAction.ps1')
}

Describe "New-SyntheticAuditLogFixture" {
    Context "Reproducibility" {
        It "Produces identical output for the same seed" {
            # Arrange / Act
            $arrFirst = @(New-SyntheticAuditLogFixture -Count 100 -Seed 42)
            $arrSecond = @(New-SyntheticAuditLogFixture -Count 100 -Seed 42)

            # Assert
            $arrFirst.Count | Should -Be $arrSecond.Count
            for ($i = 0; $i -lt $arrFirst.Count; $i++) {
                $arrFirst[$i].TimeGenerated | Should -Be $arrSecond[$i].TimeGenerated
                $arrFirst[$i].OperationName | Should -Be $arrSecond[$i].OperationName
                $arrFirst[$i].Category | Should -Be $arrSecond[$i].Category
                $arrFirst[$i].PrincipalKey | Should -Be $arrSecond[$i].PrincipalKey
                $arrFirst[$i].PrincipalType | Should -Be $arrSecond[$i].PrincipalType
                $arrFirst[$i].PrincipalUPN | Should -Be $arrSecond[$i].PrincipalUPN
                $arrFirst[$i].AppId | Should -Be $arrSecond[$i].AppId
                $arrFirst[$i].CorrelationId | Should -Be $arrSecond[$i].CorrelationId
                $arrFirst[$i].RecordId | Should -Be $arrSecond[$i].RecordId
            }
        }

        It "Produces different output for different seeds" {
            # Arrange / Act
            $arrSeed42 = @(New-SyntheticAuditLogFixture -Count 50 -Seed 42)
            $arrSeed99 = @(New-SyntheticAuditLogFixture -Count 50 -Seed 99)

            # Assert - at least one field should differ
            $boolAnyDiff = $false
            for ($i = 0; $i -lt [Math]::Min($arrSeed42.Count, $arrSeed99.Count); $i++) {
                if ($arrSeed42[$i].RecordId -ne $arrSeed99[$i].RecordId) {
                    $boolAnyDiff = $true
                    break
                }
            }
            $boolAnyDiff | Should -BeTrue
        }
    }

    Context "Parameter honoring" {
        It "Emits the requested -Count of rows" {
            # Arrange / Act
            $arrRows = @(New-SyntheticAuditLogFixture -Count 200 -Seed 42)

            # Assert
            $arrRows.Count | Should -Be 200
        }

        It "Honors -DuplicateRatio within tolerance" {
            # Arrange
            $intCount = 1000
            $dblExpectedRatio = 0.3

            # Act
            $arrRows = @(New-SyntheticAuditLogFixture -Count $intCount -DuplicateRatio $dblExpectedRatio -Seed 42)

            # Assert - count duplicate rows by looking for shared CorrelationIds
            $arrRows.Count | Should -Be $intCount

            # Group by CorrelationId (excluding empty). Rows sharing the same
            # CorrelationId + OperationName + PrincipalKey are duplicates.
            $hashGroups = @{}
            foreach ($objRow in $arrRows) {
                if ([string]::IsNullOrEmpty($objRow.CorrelationId)) {
                    continue
                }
                $strKey = ('{0}|{1}|{2}' -f $objRow.CorrelationId, $objRow.OperationName, $objRow.PrincipalKey)
                if (-not $hashGroups.ContainsKey($strKey)) {
                    $hashGroups[$strKey] = 0
                }
                $hashGroups[$strKey]++
            }
            $intDuplicates = 0
            foreach ($strKey in $hashGroups.Keys) {
                if ($hashGroups[$strKey] -gt 1) {
                    $intDuplicates += ($hashGroups[$strKey] - 1)
                }
            }
            $dblActualRatio = $intDuplicates / $intCount
            $dblActualRatio | Should -BeGreaterOrEqual ($dblExpectedRatio - 0.05)
            $dblActualRatio | Should -BeLessOrEqual ($dblExpectedRatio + 0.05)
        }

        It "Honors -NullCorrelationIdRatio within tolerance" {
            # Arrange
            $intCount = 1000
            $dblExpectedRatio = 0.1

            # Act
            $arrRows = @(New-SyntheticAuditLogFixture -Count $intCount -NullCorrelationIdRatio $dblExpectedRatio -DuplicateRatio 0.0 -Seed 42)

            # Assert
            $intNullCorr = ($arrRows | Where-Object { [string]::IsNullOrEmpty($_.CorrelationId) }).Count
            $dblActualRatio = $intNullCorr / $intCount
            $dblActualRatio | Should -BeGreaterOrEqual ($dblExpectedRatio - 0.03)
            $dblActualRatio | Should -BeLessOrEqual ($dblExpectedRatio + 0.03)
        }

        It "Honors -UnmappedActivityRatio within tolerance" {
            # Arrange
            $intCount = 1000
            $dblExpectedRatio = 0.2

            # Act
            $arrRows = @(New-SyntheticAuditLogFixture -Count $intCount -UnmappedActivityRatio $dblExpectedRatio -DuplicateRatio 0.0 -Seed 42)

            # Assert - unmapped rows have OperationName starting with "SyntheticUnmapped-"
            $intUnmapped = ($arrRows | Where-Object { $_.OperationName -like 'SyntheticUnmapped-*' }).Count
            $dblActualRatio = $intUnmapped / $intCount
            $dblActualRatio | Should -BeGreaterOrEqual ($dblExpectedRatio - 0.03)
            $dblActualRatio | Should -BeLessOrEqual ($dblExpectedRatio + 0.03)
        }

        It "Honors -ServicePrincipalRatio within tolerance" {
            # Arrange
            $intCount = 1000
            $dblExpectedRatio = 0.3

            # Act
            $arrRows = @(New-SyntheticAuditLogFixture -Count $intCount -ServicePrincipalRatio $dblExpectedRatio -DuplicateRatio 0.0 -Seed 42)

            # Assert
            $intSp = ($arrRows | Where-Object { $_.PrincipalType -eq 'ServicePrincipal' }).Count
            $dblActualRatio = $intSp / $intCount
            $dblActualRatio | Should -BeGreaterOrEqual ($dblExpectedRatio - 0.05)
            $dblActualRatio | Should -BeLessOrEqual ($dblExpectedRatio + 0.05)
        }

        It "Honors -DuplicateRatio 0.0 producing no duplicates" {
            # Arrange / Act
            $arrRows = @(New-SyntheticAuditLogFixture -Count 200 -DuplicateRatio 0.0 -Seed 42)

            # Assert - all RecordIds should be unique
            $arrRows.Count | Should -Be 200
            $intUnique = ($arrRows | Select-Object -ExpandProperty RecordId -Unique).Count
            $intUnique | Should -Be 200
        }
    }

    Context "Output shape" {
        BeforeAll {
            $script:arrRows = @(New-SyntheticAuditLogFixture -Count 100 -Seed 42)
        }

        It "Emits pscustomobject instances" {
            # Assert
            $script:arrRows | Should -Not -BeNullOrEmpty
            foreach ($objRow in $script:arrRows) {
                $objRow | Should -BeOfType [pscustomobject]
            }
        }

        It "Each row has all required properties" {
            # Assert
            $script:arrRows | Should -Not -BeNullOrEmpty
            $arrExpectedProps = @('TimeGenerated', 'OperationName', 'Category', 'PrincipalKey', 'PrincipalType', 'PrincipalUPN', 'AppId', 'CorrelationId', 'RecordId')
            foreach ($objRow in $script:arrRows) {
                foreach ($strProp in $arrExpectedProps) {
                    $objRow.PSObject.Properties.Name | Should -Contain $strProp
                }
            }
        }

        It "TimeGenerated values are ISO-8601 strings" {
            # Assert
            $script:arrRows | Should -Not -BeNullOrEmpty
            foreach ($objRow in $script:arrRows) {
                $objRow.TimeGenerated | Should -BeOfType [string]
                $objParsed = [datetimeoffset]::MinValue
                $boolParsed = [datetimeoffset]::TryParse(
                    $objRow.TimeGenerated,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::AssumeUniversal,
                    [ref]$objParsed
                )
                $boolParsed | Should -BeTrue
            }
        }

        It "PrincipalType is User or ServicePrincipal" {
            # Assert
            $script:arrRows | Should -Not -BeNullOrEmpty
            foreach ($objRow in $script:arrRows) {
                $objRow.PrincipalType | Should -BeIn @('User', 'ServicePrincipal')
            }
        }

        It "ServicePrincipal rows have AppId equal to PrincipalKey and empty PrincipalUPN" {
            # Assert
            $arrSpRows = @($script:arrRows | Where-Object { $_.PrincipalType -eq 'ServicePrincipal' })
            $arrSpRows | Should -Not -BeNullOrEmpty
            foreach ($objRow in $arrSpRows) {
                $objRow.AppId | Should -Be $objRow.PrincipalKey
                $objRow.PrincipalUPN | Should -Be ''
            }
        }

        It "User rows have empty AppId and non-empty PrincipalUPN" {
            # Assert
            $arrUserRows = @($script:arrRows | Where-Object { $_.PrincipalType -eq 'User' })
            $arrUserRows | Should -Not -BeNullOrEmpty
            foreach ($objRow in $arrUserRows) {
                $objRow.AppId | Should -Be ''
                $objRow.PrincipalUPN | Should -Not -BeNullOrEmpty
            }
        }

        It "RecordId values are unique across all rows" {
            # Assert
            $intUnique = ($script:arrRows | Select-Object -ExpandProperty RecordId -Unique).Count
            $intUnique | Should -Be $script:arrRows.Count
        }
    }

    Context "Retry-duplicate invariants" {
        BeforeAll {
            $script:arrDupRows = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.5 -Seed 42)
        }

        It "Duplicate rows share expected fields with their parent" {
            # Arrange - find groups by CorrelationId + OperationName + PrincipalKey
            $hashGroups = @{}
            foreach ($objRow in $script:arrDupRows) {
                if ([string]::IsNullOrEmpty($objRow.CorrelationId)) {
                    continue
                }
                $strKey = ('{0}|{1}|{2}' -f $objRow.CorrelationId, $objRow.OperationName, $objRow.PrincipalKey)
                if (-not $hashGroups.ContainsKey($strKey)) {
                    $hashGroups[$strKey] = New-Object System.Collections.Generic.List[pscustomobject]
                }
                [void]($hashGroups[$strKey].Add($objRow))
            }

            # Assert - groups with more than 1 member are duplicate groups
            $boolFoundDuplicateGroup = $false
            foreach ($strKey in $hashGroups.Keys) {
                $arrGroup = $hashGroups[$strKey]
                if ($arrGroup.Count -le 1) {
                    continue
                }
                $boolFoundDuplicateGroup = $true

                $objFirst = $arrGroup[0]
                for ($i = 1; $i -lt $arrGroup.Count; $i++) {
                    $objDup = $arrGroup[$i]

                    # Shared fields
                    $objDup.PrincipalKey | Should -Be $objFirst.PrincipalKey
                    $objDup.PrincipalType | Should -Be $objFirst.PrincipalType
                    $objDup.PrincipalUPN | Should -Be $objFirst.PrincipalUPN
                    $objDup.AppId | Should -Be $objFirst.AppId
                    $objDup.OperationName | Should -Be $objFirst.OperationName
                    $objDup.Category | Should -Be $objFirst.Category
                    $objDup.CorrelationId | Should -Be $objFirst.CorrelationId

                    # Differing fields
                    $objDup.RecordId | Should -Not -Be $objFirst.RecordId
                }
            }
            $boolFoundDuplicateGroup | Should -BeTrue
        }
    }
}
