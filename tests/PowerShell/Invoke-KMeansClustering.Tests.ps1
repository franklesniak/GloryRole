BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strSrcPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-SquaredEuclideanDistance.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-FarthestPointIndex.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Invoke-KMeansClustering.ps1')
}

Describe "Invoke-KMeansClustering" {
    Context "When clustering well-separated data" {
        BeforeAll {
            # Two clearly separated clusters
            $script:arrVectorRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(1.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(1.1, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'a3'; Vector = [double[]]@(0.9, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(0.0, 1.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(0.1, 1.1) }
                [pscustomobject]@{ PrincipalKey = 'b3'; Vector = [double[]]@(0.1, 0.9) }
            )
        }

        It "Returns assignments for all principals" {
            # Act
            $objResult = Invoke-KMeansClustering -VectorRows $script:arrVectorRows -K 2

            # Assert
            $objResult.Assignments.Count | Should -Be 6
        }

        It "Assigns same-cluster points to same cluster" {
            # Act
            $objResult = Invoke-KMeansClustering -VectorRows $script:arrVectorRows -K 2

            # Assert
            $intA1Cluster = $objResult.Assignments['a1']
            $intA2Cluster = $objResult.Assignments['a2']
            $intA3Cluster = $objResult.Assignments['a3']
            $intA1Cluster | Should -Be $intA2Cluster
            $intA2Cluster | Should -Be $intA3Cluster
        }

        It "Assigns different-cluster points to different clusters" {
            # Act
            $objResult = Invoke-KMeansClustering -VectorRows $script:arrVectorRows -K 2

            # Assert
            $objResult.Assignments['a1'] | Should -Not -Be $objResult.Assignments['b1']
        }

        It "Returns correct K" {
            # Act
            $objResult = Invoke-KMeansClustering -VectorRows $script:arrVectorRows -K 2

            # Assert
            $objResult.K | Should -Be 2
        }

        It "Returns non-negative SSE" {
            # Act
            $objResult = Invoke-KMeansClustering -VectorRows $script:arrVectorRows -K 2

            # Assert
            $objResult.SSE | Should -BeGreaterOrEqual 0.0
        }

        It "Is deterministic with same seed" {
            # Act
            $objResult1 = Invoke-KMeansClustering -VectorRows $script:arrVectorRows -K 2 -Seed 42
            $objResult2 = Invoke-KMeansClustering -VectorRows $script:arrVectorRows -K 2 -Seed 42

            # Assert
            $objResult1.SSE | Should -Be $objResult2.SSE
        }
    }

    Context "When K is invalid" {
        It "Throws when K is less than 2" {
            # Arrange
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a'; Vector = [double[]]@(1.0) }
                [pscustomobject]@{ PrincipalKey = 'b'; Vector = [double[]]@(2.0) }
            )

            # Act / Assert
            { Invoke-KMeansClustering -VectorRows $arrRows -K 1 } | Should -Throw
        }

        It "Throws when K exceeds N" {
            # Arrange
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a'; Vector = [double[]]@(1.0) }
                [pscustomobject]@{ PrincipalKey = 'b'; Vector = [double[]]@(2.0) }
            )

            # Act / Assert
            { Invoke-KMeansClustering -VectorRows $arrRows -K 3 } | Should -Throw
        }
    }

    Context "When verifying output structure" {
        BeforeAll {
            # Arrange
            $script:arrVectorRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(1.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(1.1, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'a3'; Vector = [double[]]@(0.9, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(0.0, 1.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(0.1, 1.1) }
                [pscustomobject]@{ PrincipalKey = 'b3'; Vector = [double[]]@(0.1, 0.9) }
            )

            # Act
            $script:objResult = Invoke-KMeansClustering -VectorRows $script:arrVectorRows -K 2
        }

        It "Returns a pscustomobject" {
            # Assert
            $script:objResult | Should -BeOfType [pscustomobject]
        }

        It "Contains exactly the expected property names" {
            # Arrange
            $arrExpectedProperties = @('K', 'Assignments', 'Centroids', 'SSE') | Sort-Object

            # Act
            $arrActualProperties = @($script:objResult.PSObject.Properties.Name) | Sort-Object

            # Assert
            $arrActualProperties | Should -Be $arrExpectedProperties
        }

        It "Returns K as an int" {
            # Assert
            $script:objResult.K | Should -BeOfType [int]
        }

        It "Returns Assignments as a hashtable" {
            # Assert
            $script:objResult.Assignments | Should -BeOfType [hashtable]
        }

        It "Returns Centroids as a List of double arrays" {
            # Assert
            ($script:objResult.Centroids -is [System.Collections.Generic.List[double[]]]) | Should -BeTrue
        }

        It "Returns SSE as a double" {
            # Assert
            $script:objResult.SSE | Should -BeOfType [double]
        }

        It "Returns Centroids.Count equal to K" {
            # Assert
            $script:objResult.Centroids.Count | Should -Be $script:objResult.K
        }
    }
}
