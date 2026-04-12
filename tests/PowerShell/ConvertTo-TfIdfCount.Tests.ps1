BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-TfIdfCount.ps1')
}

Describe "ConvertTo-TfIdfCount" {
    Context "When given a multi-principal input" {
        It "Computes basic multi-principal TF-IDF values correctly" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'read'; Count = 2.0 }
                [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'delete'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'user-b'; Action = 'read'; Count = 5.0 }
            )
            # N = 2
            # 'read': df = 2, IDF = log((1+2)/(1+2)) + 1 = log(1) + 1 = 1.0
            # 'delete': df = 1, IDF = log((1+2)/(1+1)) + 1 = log(1.5) + 1
            $dblDeleteIdf = [Math]::Log((1.0 + 2.0) / (1.0 + 1.0)) + 1.0

            # Act
            $arrResult = @(ConvertTo-TfIdfCount -Counts $arrCounts)

            # Assert
            $arrFilteredUserARead = @($arrResult | Where-Object { $_.PrincipalKey -eq 'user-a' -and $_.Action -eq 'read' })
            $arrFilteredUserARead | Should -Not -BeNullOrEmpty
            $arrFilteredUserARead.Count | Should -Be 1
            $arrFilteredUserARead[0].Count | Should -Be 2.0

            $arrFilteredUserADelete = @($arrResult | Where-Object { $_.PrincipalKey -eq 'user-a' -and $_.Action -eq 'delete' })
            $arrFilteredUserADelete | Should -Not -BeNullOrEmpty
            $arrFilteredUserADelete.Count | Should -Be 1
            [Math]::Abs($arrFilteredUserADelete[0].Count - (1.0 * $dblDeleteIdf)) | Should -BeLessThan 0.0001

            $arrFilteredUserBRead = @($arrResult | Where-Object { $_.PrincipalKey -eq 'user-b' -and $_.Action -eq 'read' })
            $arrFilteredUserBRead | Should -Not -BeNullOrEmpty
            $arrFilteredUserBRead.Count | Should -Be 1
            $arrFilteredUserBRead[0].Count | Should -Be 5.0
        }

        It "Uses the smoothed IDF formula correctly for unique actions" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'write'; Count = 4.0 }
                [pscustomobject]@{ PrincipalKey = 'user-b'; Action = 'read'; Count = 3.0 }
                [pscustomobject]@{ PrincipalKey = 'user-c'; Action = 'read'; Count = 2.0 }
            )
            # N = 3
            # 'write': df = 1, IDF = log((1+3)/(1+1)) + 1 = log(2) + 1
            # 'read': df = 2, IDF = log((1+3)/(1+2)) + 1 = log(4/3) + 1
            $dblExpectedWriteIdf = [Math]::Log((1.0 + 3.0) / (1.0 + 1.0)) + 1.0
            $dblExpectedWriteCount = 4.0 * $dblExpectedWriteIdf

            # Act
            $arrResult = @(ConvertTo-TfIdfCount -Counts $arrCounts)

            # Assert
            $arrFiltered = @($arrResult | Where-Object { $_.PrincipalKey -eq 'user-a' -and $_.Action -eq 'write' })
            $arrFiltered | Should -Not -BeNullOrEmpty
            $arrFiltered.Count | Should -Be 1
            [Math]::Abs($arrFiltered[0].Count - $dblExpectedWriteCount) | Should -BeLessThan 0.0001
        }

        It "Preserves the same number of output rows as input rows" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'read'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'write'; Count = 2.0 }
                [pscustomobject]@{ PrincipalKey = 'user-b'; Action = 'read'; Count = 3.0 }
                [pscustomobject]@{ PrincipalKey = 'user-b'; Action = 'delete'; Count = 4.0 }
            )

            # Act
            $arrResult = @(ConvertTo-TfIdfCount -Counts $arrCounts)

            # Assert
            $arrResult.Count | Should -Be $arrCounts.Count
        }
    }

    Context "When given a single-principal input" {
        It "Returns output Count equal to input Count for single principal and single action" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'read'; Count = 3.0 }
            )
            # N = 1, df = 1, IDF = log((1+1)/(1+1)) + 1 = log(1) + 1 = 1.0

            # Act
            $arrResult = @(ConvertTo-TfIdfCount -Counts $arrCounts)

            # Assert
            $arrFiltered = @($arrResult | Where-Object { $_.Action -eq 'read' })
            $arrFiltered | Should -Not -BeNullOrEmpty
            $arrFiltered.Count | Should -Be 1
            $arrFiltered[0].Count | Should -Be 3.0
        }

        It "Returns output Count equal to input Count for single principal with multiple actions" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'read'; Count = 2.0 }
                [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'write'; Count = 5.0 }
                [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'delete'; Count = 1.0 }
            )
            # N = 1, df = 1 for all actions, IDF = 1.0 for all

            # Act
            $arrResult = @(ConvertTo-TfIdfCount -Counts $arrCounts)

            # Assert
            $arrFilteredRead = @($arrResult | Where-Object { $_.Action -eq 'read' })
            $arrFilteredRead | Should -Not -BeNullOrEmpty
            $arrFilteredRead.Count | Should -Be 1
            $arrFilteredRead[0].Count | Should -Be 2.0

            $arrFilteredWrite = @($arrResult | Where-Object { $_.Action -eq 'write' })
            $arrFilteredWrite | Should -Not -BeNullOrEmpty
            $arrFilteredWrite.Count | Should -Be 1
            $arrFilteredWrite[0].Count | Should -Be 5.0

            $arrFilteredDelete = @($arrResult | Where-Object { $_.Action -eq 'delete' })
            $arrFilteredDelete | Should -Not -BeNullOrEmpty
            $arrFilteredDelete.Count | Should -Be 1
            $arrFilteredDelete[0].Count | Should -Be 1.0
        }
    }

    Context "When given edge-case input" {
        It "Returns no objects for an empty input array" {
            # Arrange
            $arrCounts = @()

            # Act
            $arrResult = @(ConvertTo-TfIdfCount -Counts $arrCounts)

            # Assert
            $arrResult.Count | Should -Be 0
        }

        It "Returns output objects with correct property names and types" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'read'; Count = 3.0 }
            )

            # Act
            $arrResult = @(ConvertTo-TfIdfCount -Counts $arrCounts)

            # Assert
            $arrResult.Count | Should -Be 1
            $objOutput = $arrResult[0]
            $arrPropertyNames = @($objOutput.PSObject.Properties.Name)
            $arrPropertyNames | Should -Contain 'PrincipalKey'
            $arrPropertyNames | Should -Contain 'Action'
            $arrPropertyNames | Should -Contain 'Count'
            $objOutput.PrincipalKey | Should -BeOfType [string]
            $objOutput.Action | Should -BeOfType [string]
            $objOutput.Count | Should -BeOfType [double]
        }

        It "Returns pscustomobject instances" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'read'; Count = 3.0 }
            )

            # Act
            $arrResult = @(ConvertTo-TfIdfCount -Counts $arrCounts)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0] | Should -BeOfType [pscustomobject]
        }
    }
}
