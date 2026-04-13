BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-SquaredEuclideanDistance.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-ApproximateSilhouetteScore.ps1')
}

Describe "Get-ApproximateSilhouetteScore" {
    Context "When clusters are well-separated" {
        BeforeAll {
            # Arrange
            $script:arrVectorRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a3'; Vector = [double[]]@(0.0, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(10.0, 10.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(10.1, 10.0) }
                [pscustomobject]@{ PrincipalKey = 'b3'; Vector = [double[]]@(10.0, 10.1) }
            )

            $script:objKmResult = [pscustomobject]@{
                K = 2
                Assignments = @{
                    'a1' = 0; 'a2' = 0; 'a3' = 0
                    'b1' = 1; 'b2' = 1; 'b3' = 1
                }
            }

            # Act
            $script:dblScore = Get-ApproximateSilhouetteScore -VectorRows $script:arrVectorRows -KMeansResult $script:objKmResult -SampleSize 6 -Seed 42
        }

        It "Returns a score greater than 0.8 for well-separated clusters" {
            # Assert
            $script:dblScore | Should -BeGreaterThan 0.8
        }

        It "Returns a value within the valid silhouette range" {
            # Assert
            $script:dblScore | Should -BeGreaterOrEqual -1.0
            $script:dblScore | Should -BeLessOrEqual 1.0
        }
    }

    Context "When given a single data point" {
        It "Returns 0.0" {
            # Arrange
            $arrVectorRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(1.0, 2.0) }
            )
            $objKmResult = [pscustomobject]@{
                K = 1
                Assignments = @{ 'a1' = 0 }
            }

            # Act
            $dblScore = Get-ApproximateSilhouetteScore -VectorRows $arrVectorRows -KMeansResult $objKmResult

            # Assert
            $dblScore | Should -Be 0.0
        }
    }

    Context "When given exactly two data points" {
        It "Returns 0.0" {
            # Arrange
            $arrVectorRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(10.0, 10.0) }
            )
            $objKmResult = [pscustomobject]@{
                K = 2
                Assignments = @{ 'a1' = 0; 'b1' = 1 }
            }

            # Act
            $dblScore = Get-ApproximateSilhouetteScore -VectorRows $arrVectorRows -KMeansResult $objKmResult

            # Assert
            $dblScore | Should -Be 0.0
        }
    }

    Context "When comparing good vs bad clustering" {
        It "Returns a higher score for good clustering than bad clustering" {
            # Arrange - same data, two different clusterings
            $arrVectorRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'a3'; Vector = [double[]]@(0.2, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(10.0, 10.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(10.1, 10.1) }
                [pscustomobject]@{ PrincipalKey = 'b3'; Vector = [double[]]@(10.2, 10.0) }
            )

            # Good clustering: natural groups
            $objGoodKm = [pscustomobject]@{
                K = 2
                Assignments = @{
                    'a1' = 0; 'a2' = 0; 'a3' = 0
                    'b1' = 1; 'b2' = 1; 'b3' = 1
                }
            }

            # Bad clustering: scrambled assignments
            $objBadKm = [pscustomobject]@{
                K = 2
                Assignments = @{
                    'a1' = 0; 'b1' = 0; 'a3' = 0
                    'a2' = 1; 'b2' = 1; 'b3' = 1
                }
            }

            # Act
            $dblGoodScore = Get-ApproximateSilhouetteScore -VectorRows $arrVectorRows -KMeansResult $objGoodKm -SampleSize 6 -Seed 42
            $dblBadScore = Get-ApproximateSilhouetteScore -VectorRows $arrVectorRows -KMeansResult $objBadKm -SampleSize 6 -Seed 42

            # Assert
            $dblGoodScore | Should -BeGreaterThan $dblBadScore
        }
    }

    Context "When using the same seed" {
        It "Returns identical results for both calls" {
            # Arrange
            $arrVectorRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'a3'; Vector = [double[]]@(0.2, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(10.0, 10.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(10.1, 10.1) }
                [pscustomobject]@{ PrincipalKey = 'b3'; Vector = [double[]]@(10.2, 10.0) }
            )
            $objKmResult = [pscustomobject]@{
                K = 2
                Assignments = @{
                    'a1' = 0; 'a2' = 0; 'a3' = 0
                    'b1' = 1; 'b2' = 1; 'b3' = 1
                }
            }

            # Act
            $dblScore1 = Get-ApproximateSilhouetteScore -VectorRows $arrVectorRows -KMeansResult $objKmResult -SampleSize 4 -Seed 99
            $dblScore2 = Get-ApproximateSilhouetteScore -VectorRows $arrVectorRows -KMeansResult $objKmResult -SampleSize 4 -Seed 99

            # Assert
            $dblScore2 | Should -Be $dblScore1
        }
    }
}
