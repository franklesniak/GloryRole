BeforeAll {
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-NormalizedAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Import-PrincipalActionCountFromCsv.ps1')
}

Describe "Import-PrincipalActionCountFromCsv" {
    Context "When given a valid CSV file" {
        It "Imports sparse triples correctly" {
            # Arrange
            $strPath = Join-Path -Path $repoRoot -ChildPath (Join-Path -Path 'samples' -ChildPath 'principal_action_counts.csv')

            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $strPath)

            # Assert
            $arrResult.Count | Should -BeGreaterThan 0
            $arrResult[0].PrincipalKey | Should -Not -BeNullOrEmpty
            $arrResult[0].Action | Should -Not -BeNullOrEmpty
            $arrResult[0].Count | Should -BeGreaterThan 0
        }

        It "Normalizes actions to lowercase" {
            # Arrange
            $strPath = Join-Path -Path $repoRoot -ChildPath (Join-Path -Path 'samples' -ChildPath 'principal_action_counts.csv')

            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $strPath)

            # Assert
            foreach ($objRow in $arrResult) {
                $objRow.Action | Should -BeExactly $objRow.Action.ToLowerInvariant()
            }
        }
    }

    Context "When verifying output contract" {
        It "Returns objects with exactly PrincipalKey, Action, and Count properties" {
            # Arrange
            $strPath = Join-Path -Path $repoRoot -ChildPath (Join-Path -Path 'samples' -ChildPath 'principal_action_counts.csv')

            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $strPath)

            # Assert
            foreach ($objRow in $arrResult) {
                $arrPropertyNames = @($objRow.PSObject.Properties.Name | Sort-Object)
                $arrPropertyNames | Should -Be @('Action', 'Count', 'PrincipalKey')
            }
        }
    }

    Context "When CSV contains blank actions" {
        BeforeAll {
            $strTempFileName = [System.IO.Path]::GetRandomFileName()
            $script:strTempCsvPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $strTempFileName
            $strCsvContent = @(
                'PrincipalKey,Action,Count'
                'user1,microsoft.authorization/roleassignments/write,5'
                'user2,,3'
                'user3,   ,2'
                'user4,microsoft.compute/virtualmachines/start/action,1'
            ) -join [System.Environment]::NewLine
            Set-Content -LiteralPath $script:strTempCsvPath -Value $strCsvContent -Encoding UTF8
        }

        AfterAll {
            if (Test-Path -LiteralPath $script:strTempCsvPath) {
                Remove-Item -LiteralPath $script:strTempCsvPath -Force
            }
        }

        It "Skips rows with empty or whitespace-only actions" {
            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $script:strTempCsvPath)

            # Assert
            $arrResult.Count | Should -Be 2
            $arrResult[0].PrincipalKey | Should -Be 'user1'
            $arrResult[1].PrincipalKey | Should -Be 'user4'
        }
    }

    Context "When given a nonexistent file" {
        It "Throws an error" {
            # Act / Assert
            { Import-PrincipalActionCountFromCsv -Path 'nonexistent.csv' } | Should -Throw
        }
    }
}
