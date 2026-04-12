BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-SquaredEuclideanDistance.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-CalinskiHarabaszIndex.ps1')
}

Describe "Get-CalinskiHarabaszIndex" {
    Context "When clusters are well-separated" {
        BeforeAll {
            $script:arrVectorRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(10.0, 10.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(10.1, 10.0) }
            )

            $script:objKmResult = [pscustomobject]@{
                K = 2
                Assignments = @{
                    'a1' = 0; 'a2' = 0
                    'b1' = 1; 'b2' = 1
                }
                Centroids = @(
                    [double[]]@(0.05, 0.0),
                    [double[]]@(10.05, 10.0)
                )
                SSE = 0.01
            }
        }

        It "Returns a high index for well-separated clusters" {
            # Act
            $dblResult = Get-CalinskiHarabaszIndex -VectorRows $script:arrVectorRows -KMeansResult $script:objKmResult

            # Assert - well-separated clusters should have high CH
            $dblResult | Should -BeGreaterThan 100
        }

        It "Returns a positive value" {
            # Act
            $dblResult = Get-CalinskiHarabaszIndex -VectorRows $script:arrVectorRows -KMeansResult $script:objKmResult

            # Assert
            $dblResult | Should -BeGreaterThan 0.0
        }
    }

    Context "When K is less than 2" {
        It "Returns 0.0" {
            # Arrange
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a'; Vector = [double[]]@(1.0) }
            )
            $objResult = [pscustomobject]@{
                K = 1
                Assignments = @{ 'a' = 0 }
                Centroids = @([double[]]@(1.0))
                SSE = 0.0
            }

            # Act
            $dblCh = Get-CalinskiHarabaszIndex -VectorRows $arrRows -KMeansResult $objResult

            # Assert
            $dblCh | Should -Be 0.0
        }
    }

    Context "When N is less than or equal to K" {
        It "Returns 0.0 when N equals K" {
            # Arrange
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b'; Vector = [double[]]@(10.0, 10.0) }
            )
            $objResult = [pscustomobject]@{
                K = 2
                Assignments = @{ 'a' = 0; 'b' = 1 }
                Centroids = @(
                    [double[]]@(0.0, 0.0),
                    [double[]]@(10.0, 10.0)
                )
                SSE = 0.0
            }

            # Act
            $dblCh = Get-CalinskiHarabaszIndex -VectorRows $arrRows -KMeansResult $objResult

            # Assert
            $dblCh | Should -Be 0.0
        }
    }

    Context "When WGSS is zero" {
        It "Returns PositiveInfinity when all points lie on centroids" {
            # Arrange - 4 points, 2 identical at each centroid (SSE = 0)
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(10.0, 10.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(10.0, 10.0) }
            )
            $objResult = [pscustomobject]@{
                K = 2
                Assignments = @{ 'a1' = 0; 'a2' = 0; 'b1' = 1; 'b2' = 1 }
                Centroids = @(
                    [double[]]@(0.0, 0.0),
                    [double[]]@(10.0, 10.0)
                )
                SSE = 0.0
            }

            # Act
            $dblCh = Get-CalinskiHarabaszIndex -VectorRows $arrRows -KMeansResult $objResult

            # Assert
            $dblCh | Should -Be ([double]::PositiveInfinity)
        }
    }

    Context "When an unexpected error occurs" {
        It "Returns -1.0 on computation failure" {
            # Arrange - KMeansResult with null Centroids to trigger an error
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(10.0, 10.0) }
            )
            $objResult = [pscustomobject]@{
                K = 2
                Assignments = @{ 'a1' = 0; 'a2' = 0; 'b1' = 1 }
                Centroids = $null
                SSE = 0.01
            }

            # Act
            $dblCh = Get-CalinskiHarabaszIndex -VectorRows $arrRows -KMeansResult $objResult -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            # Assert
            $dblCh | Should -Be (-1.0)
        }
    }

    Context "When comparing good vs bad clustering" {
        It "Returns higher index for better clustering" {
            # Arrange - same data, two different clusterings
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(5.0, 5.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(5.1, 5.1) }
            )

            # Good clustering: natural groups
            $objGood = [pscustomobject]@{
                K = 2
                Assignments = @{ 'a1' = 0; 'a2' = 0; 'b1' = 1; 'b2' = 1 }
                Centroids = @([double[]]@(0.05, 0.05), [double[]]@(5.05, 5.05))
                SSE = 0.02
            }

            # Bad clustering: split natural groups
            $objBad = [pscustomobject]@{
                K = 2
                Assignments = @{ 'a1' = 0; 'b1' = 0; 'a2' = 1; 'b2' = 1 }
                Centroids = @([double[]]@(2.5, 2.5), [double[]]@(2.6, 2.6))
                SSE = 25.0
            }

            # Act
            $dblGoodCh = Get-CalinskiHarabaszIndex -VectorRows $arrRows -KMeansResult $objGood
            $dblBadCh = Get-CalinskiHarabaszIndex -VectorRows $arrRows -KMeansResult $objBad

            # Assert - good clustering should have higher CH
            $dblGoodCh | Should -BeGreaterThan $dblBadCh
        }
    }
}
