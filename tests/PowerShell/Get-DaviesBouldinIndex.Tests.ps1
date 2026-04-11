BeforeAll {
    $strSrcPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-SquaredEuclideanDistance.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-DaviesBouldinIndex.ps1')
}

Describe "Get-DaviesBouldinIndex" {
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

        It "Returns a low index for well-separated clusters" {
            # Arrange - see BeforeAll

            # Act
            $dblResult = Get-DaviesBouldinIndex -VectorRows $script:arrVectorRows -KMeansResult $script:objKmResult

            # Assert - well-separated clusters should have a low DB index
            $dblResult | Should -BeLessThan 0.1
        }

        It "Returns a non-negative value" {
            # Arrange - see BeforeAll

            # Act
            $dblResult = Get-DaviesBouldinIndex -VectorRows $script:arrVectorRows -KMeansResult $script:objKmResult

            # Assert
            $dblResult | Should -BeGreaterOrEqual 0.0
        }

        It "Returns a value of type [double]" {
            # Arrange - see BeforeAll

            # Act
            $dblResult = Get-DaviesBouldinIndex -VectorRows $script:arrVectorRows -KMeansResult $script:objKmResult

            # Assert
            $dblResult | Should -BeOfType [double]
        }
    }

    Context "When K is less than 2" {
        It "Returns 0.0 when K is 1" {
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
            $dblDb = Get-DaviesBouldinIndex -VectorRows $arrRows -KMeansResult $objResult

            # Assert
            $dblDb | Should -Be 0.0
        }

        It "Returns 0.0 when K is 0" {
            # Arrange
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a'; Vector = [double[]]@(1.0) }
            )
            $objResult = [pscustomobject]@{
                K = 0
                Assignments = @{}
                Centroids = @()
                SSE = 0.0
            }

            # Act
            $dblDb = Get-DaviesBouldinIndex -VectorRows $arrRows -KMeansResult $objResult

            # Assert
            $dblDb | Should -Be 0.0
        }
    }

    Context "When cluster centroids are coincident" {
        It "Returns PositiveInfinity and emits a warning" {
            # Arrange
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(1.0, 2.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(1.1, 2.1) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(1.0, 2.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(1.1, 2.1) }
            )
            $objResult = [pscustomobject]@{
                K = 2
                Assignments = @{
                    'a1' = 0; 'a2' = 0
                    'b1' = 1; 'b2' = 1
                }
                Centroids = @(
                    [double[]]@(1.05, 2.05),
                    [double[]]@(1.05, 2.05)
                )
                SSE = 0.02
            }

            # Act
            $dblDb = Get-DaviesBouldinIndex -VectorRows $arrRows -KMeansResult $objResult -WarningVariable warn -WarningAction SilentlyContinue

            # Assert
            $warn.Count | Should -BeGreaterOrEqual 1
            $dblDb | Should -Be ([double]::PositiveInfinity)
        }
    }

    Context "When comparing good vs bad clustering" {
        It "Returns lower index for better clustering" {
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
            $dblGoodDb = Get-DaviesBouldinIndex -VectorRows $arrRows -KMeansResult $objGood
            $dblBadDb = Get-DaviesBouldinIndex -VectorRows $arrRows -KMeansResult $objBad

            # Assert - good clustering should have lower DB
            $dblGoodDb | Should -BeLessThan $dblBadDb
        }
    }
}
