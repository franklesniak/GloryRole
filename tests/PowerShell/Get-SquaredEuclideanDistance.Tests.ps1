BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-SquaredEuclideanDistance.ps1')
}

Describe "Get-SquaredEuclideanDistance" {
    Context "When computing distance" {
        It "Returns 0 for identical vectors" {
            # Arrange
            $arrFirstVector = [double[]]@(1.0, 2.0, 3.0)
            $arrSecondVector = [double[]]@(1.0, 2.0, 3.0)

            # Act
            $dblResult = Get-SquaredEuclideanDistance -VectorA $arrFirstVector -VectorB $arrSecondVector

            # Assert
            $dblResult | Should -Be 0.0
        }

        It "Returns correct squared distance" {
            # Arrange - (4-1)^2 + (6-2)^2 = 9 + 16 = 25
            $arrFirstVector = [double[]]@(1.0, 2.0)
            $arrSecondVector = [double[]]@(4.0, 6.0)

            # Act
            $dblResult = Get-SquaredEuclideanDistance -VectorA $arrFirstVector -VectorB $arrSecondVector

            # Assert
            $dblResult | Should -Be 25.0
        }

        It "Is symmetric" {
            # Arrange
            $arrFirstVector = [double[]]@(1.0, 5.0)
            $arrSecondVector = [double[]]@(3.0, 1.0)

            # Act
            $dblForward = Get-SquaredEuclideanDistance -VectorA $arrFirstVector -VectorB $arrSecondVector
            $dblReverse = Get-SquaredEuclideanDistance -VectorA $arrSecondVector -VectorB $arrFirstVector

            # Assert
            $dblForward | Should -Be $dblReverse
        }
    }

    Context "When computing distance for edge cases" {
        It "Returns correct squared distance for single-element vectors" {
            # Arrange
            $arrFirstVector = [double[]]@(0.0)
            $arrSecondVector = [double[]]@(5.0)

            # Act
            $dblResult = Get-SquaredEuclideanDistance -VectorA $arrFirstVector -VectorB $arrSecondVector

            # Assert
            $dblResult | Should -Be 25.0
        }

        It "Returns correct squared distance for higher-dimensional vectors" {
            # Arrange - (2-1)^2 + (4-2)^2 + (6-3)^2 + (8-4)^2 + (10-5)^2 = 1 + 4 + 9 + 16 + 25 = 55
            $arrFirstVector = [double[]]@(1.0, 2.0, 3.0, 4.0, 5.0)
            $arrSecondVector = [double[]]@(2.0, 4.0, 6.0, 8.0, 10.0)

            # Act
            $dblResult = Get-SquaredEuclideanDistance -VectorA $arrFirstVector -VectorB $arrSecondVector

            # Assert
            $dblResult | Should -Be 55.0
        }

        It "Returns correct squared distance for negative vector components" {
            # Arrange - (-1 - 1)^2 + (-2 - 2)^2 = 4 + 16 = 20
            $arrFirstVector = [double[]]@(-1.0, -2.0)
            $arrSecondVector = [double[]]@(1.0, 2.0)

            # Act
            $dblResult = Get-SquaredEuclideanDistance -VectorA $arrFirstVector -VectorB $arrSecondVector

            # Assert
            $dblResult | Should -Be 20.0
        }
    }

    Context "When given invalid input" {
        It "Throws an error for mismatched vector lengths" {
            # Arrange
            $arrShortVector = [double[]]@(1.0, 2.0)
            $arrLongVector = [double[]]@(1.0, 2.0, 3.0)

            # Act & Assert
            { Get-SquaredEuclideanDistance -VectorA $arrShortVector -VectorB $arrLongVector } | Should -Throw
        }
    }
}
