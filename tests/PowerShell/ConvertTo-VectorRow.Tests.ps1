BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'New-FeatureIndex.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-VectorRow.ps1')
}

Describe "ConvertTo-VectorRow" {
    Context "When converting counts to vectors" {
        BeforeAll {
            $script:arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'a'; Count = 5.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'b'; Count = 3.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'a'; Count = 2.0 }
            )
            $script:objIndex = New-FeatureIndex -PrincipalActionCounts $script:arrCounts
        }

        It "Produces one row per principal" {
            # Act
            $arrRows = @(ConvertTo-VectorRow -Counts $script:arrCounts -FeatureIndexObject $script:objIndex)

            # Assert
            $arrRows.Count | Should -Be 2
        }

        It "Creates vectors with correct dimension" {
            # Act
            $arrRows = @(ConvertTo-VectorRow -Counts $script:arrCounts -FeatureIndexObject $script:objIndex)

            # Assert
            $arrRows[0].Vector.Length | Should -Be 2
            $arrRows[1].Vector.Length | Should -Be 2
        }

        It "Places counts at correct indices" {
            # Act
            $arrRows = @(ConvertTo-VectorRow -Counts $script:arrCounts -FeatureIndexObject $script:objIndex)
            $objU1 = $arrRows | Where-Object { $_.PrincipalKey -eq 'u1' }

            # Assert - 'a' is index 0, 'b' is index 1
            $objU1.Vector[0] | Should -Be 5.0
            $objU1.Vector[1] | Should -Be 3.0
        }

        It "Fills zero for missing actions" {
            # Act
            $arrRows = @(ConvertTo-VectorRow -Counts $script:arrCounts -FeatureIndexObject $script:objIndex)
            $objU2 = $arrRows | Where-Object { $_.PrincipalKey -eq 'u2' }

            # Assert - u2 has 'a' but not 'b'
            $objU2.Vector[0] | Should -Be 2.0
            $objU2.Vector[1] | Should -Be 0.0
        }

        It "Computes correct TotalActions" {
            # Act
            $arrRows = @(ConvertTo-VectorRow -Counts $script:arrCounts -FeatureIndexObject $script:objIndex)
            $objU1 = $arrRows | Where-Object { $_.PrincipalKey -eq 'u1' }

            # Assert
            $objU1.TotalActions | Should -Be 8.0
        }
    }

    Context "When given a single count" {
        It "Produces exactly one vector row with correct dimension" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; Count = 7.0 }
            )
            $objIndex = New-FeatureIndex -PrincipalActionCounts $arrCounts

            # Act
            $arrRows = @(ConvertTo-VectorRow -Counts $arrCounts -FeatureIndexObject $objIndex)

            # Assert
            $arrRows.Count | Should -Be 1
            $arrRows[0].Vector.Length | Should -Be $objIndex.FeatureNames.Count
            $arrRows[0].Vector[0] | Should -Be 7.0
            $arrRows[0].TotalActions | Should -Be 7.0
        }
    }

    Context "When given duplicate principal-action pairs" {
        It "Aggregates counts for the same principal and action" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; Count = 3.0 }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; Count = 5.0 }
            )
            $objIndex = New-FeatureIndex -PrincipalActionCounts $arrCounts

            # Act
            $arrRows = @(ConvertTo-VectorRow -Counts $arrCounts -FeatureIndexObject $objIndex)

            # Assert
            $arrRows.Count | Should -Be 1
            $arrRows[0].Vector[0] | Should -Be 8.0
            $arrRows[0].TotalActions | Should -Be 8.0
        }
    }

    Context "When given unknown actions" {
        It "Silently skips actions not in the feature index" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; Count = 4.0 }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'delete'; Count = 9.0 }
            )
            # Build feature index from only 'read', excluding 'delete'
            $arrSubset = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; Count = 4.0 }
            )
            $objIndex = New-FeatureIndex -PrincipalActionCounts $arrSubset

            # Act
            $arrRows = @(ConvertTo-VectorRow -Counts $arrCounts -FeatureIndexObject $objIndex)

            # Assert
            $arrRows.Count | Should -Be 1
            $arrRows[0].Vector.Length | Should -Be 1
            $arrRows[0].Vector[0] | Should -Be 4.0
            $arrRows[0].TotalActions | Should -Be 4.0
        }
    }
}
