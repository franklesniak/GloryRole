BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-NormalizedVectorRow.ps1')
}

Describe "ConvertTo-NormalizedVectorRow" {
    Context "Default normalization (Log1P + L2)" {
        It "Produces a unit-length vector and returns the same number of rows" {
            # Arrange
            $objRow = [pscustomobject]@{ PrincipalKey = 'user1'; Vector = @(3.0, 4.0) }

            # Act
            $arrResult = @(ConvertTo-NormalizedVectorRow -VectorRows @($objRow))

            # Assert
            $arrResult.Count | Should -Be 1
            $dblNorm = [Math]::Sqrt(
                ($arrResult[0].Vector[0] * $arrResult[0].Vector[0]) +
                ($arrResult[0].Vector[1] * $arrResult[0].Vector[1])
            )
            $dblNorm | Should -BeGreaterThan 0.9999
            $dblNorm | Should -BeLessThan 1.0001
        }
    }

    Context "Log1P only (-L2 `$false)" {
        It "Applies Log1P transformation without L2 normalization" {
            # Arrange
            $objRow = [pscustomobject]@{ PrincipalKey = 'user1'; Vector = @(0.0, 1.0, 9.0) }

            # Act
            $arrResult = @(ConvertTo-NormalizedVectorRow -VectorRows @($objRow) -L2 $false)

            # Assert
            [Math]::Abs($arrResult[0].Vector[0] - 0.0) | Should -BeLessThan 0.0001
            [Math]::Abs($arrResult[0].Vector[1] - [Math]::Log(2.0)) | Should -BeLessThan 0.0001
            [Math]::Abs($arrResult[0].Vector[2] - [Math]::Log(10.0)) | Should -BeLessThan 0.0001
        }
    }

    Context "L2 only (-Log1P `$false)" {
        It "Applies L2 normalization without Log1P transformation" {
            # Arrange
            $objRow = [pscustomobject]@{ PrincipalKey = 'user1'; Vector = @(3.0, 4.0) }

            # Act
            $arrResult = @(ConvertTo-NormalizedVectorRow -VectorRows @($objRow) -Log1P $false)

            # Assert
            [Math]::Abs($arrResult[0].Vector[0] - 0.6) | Should -BeLessThan 0.0001
            [Math]::Abs($arrResult[0].Vector[1] - 0.8) | Should -BeLessThan 0.0001
        }
    }

    Context "Both disabled (-Log1P `$false -L2 `$false)" {
        It "Returns the vector unchanged" {
            # Arrange
            $objRow = [pscustomobject]@{ PrincipalKey = 'user1'; Vector = @(5.0, 10.0, 15.0) }

            # Act
            $arrResult = @(ConvertTo-NormalizedVectorRow -VectorRows @($objRow) -Log1P $false -L2 $false)

            # Assert
            $arrResult[0].Vector[0] | Should -Be 5.0
            $arrResult[0].Vector[1] | Should -Be 10.0
            $arrResult[0].Vector[2] | Should -Be 15.0
        }
    }

    Context "Zero-vector edge case" {
        It "Handles zero vector without error and returns all zeros" {
            # Arrange
            $objRow = [pscustomobject]@{ PrincipalKey = 'user1'; Vector = @(0.0, 0.0, 0.0) }

            # Act
            $arrResult = @(ConvertTo-NormalizedVectorRow -VectorRows @($objRow))

            # Assert
            $arrResult[0].Vector[0] | Should -Be 0.0
            $arrResult[0].Vector[1] | Should -Be 0.0
            $arrResult[0].Vector[2] | Should -Be 0.0
        }
    }

    Context "Streaming output" {
        It "Returns the same count as the input when multiple rows are provided" {
            # Arrange
            $objRow1 = [pscustomobject]@{ PrincipalKey = 'user1'; Vector = @(1.0, 2.0) }
            $objRow2 = [pscustomobject]@{ PrincipalKey = 'user2'; Vector = @(3.0, 4.0) }
            $objRow3 = [pscustomobject]@{ PrincipalKey = 'user3'; Vector = @(5.0, 6.0) }

            # Act
            $arrResult = @(ConvertTo-NormalizedVectorRow -VectorRows @($objRow1, $objRow2, $objRow3))

            # Assert
            $arrResult.Count | Should -Be 3
        }
    }

    Context "PrincipalKey preservation" {
        It "Preserves the PrincipalKey property on the output object" {
            # Arrange
            $objRow = [pscustomobject]@{ PrincipalKey = 'user@example.com'; Vector = @(1.0, 2.0) }

            # Act
            $arrResult = @(ConvertTo-NormalizedVectorRow -VectorRows @($objRow))

            # Assert
            $arrResult[0].PrincipalKey | Should -Be 'user@example.com'
        }
    }

    Context "In-place mutation contract" {
        It "Mutates the original object's Vector property" {
            # Arrange
            $objRow = [pscustomobject]@{ PrincipalKey = 'user1'; Vector = @(3.0, 4.0) }
            $arrOriginalVector = $objRow.Vector

            # Act
            $null = @(ConvertTo-NormalizedVectorRow -VectorRows @($objRow))

            # Assert - the original object's Vector should be modified
            $objRow.Vector | Should -Not -Be $arrOriginalVector
        }
    }

    Context "Single-element vector" {
        It "Normalizes a single non-zero element to 1.0" {
            # Arrange
            $objRow = [pscustomobject]@{ PrincipalKey = 'user1'; Vector = @(5.0) }

            # Act
            $arrResult = @(ConvertTo-NormalizedVectorRow -VectorRows @($objRow))

            # Assert
            [Math]::Abs($arrResult[0].Vector[0] - 1.0) | Should -BeLessThan 0.0001
        }
    }
}
