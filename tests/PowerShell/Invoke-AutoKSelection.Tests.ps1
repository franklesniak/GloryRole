BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strSrcPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-SquaredEuclideanDistance.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-FarthestPointIndex.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Invoke-KMeansClustering.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-ApproximateSilhouetteScore.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-DaviesBouldinIndex.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-CalinskiHarabaszIndex.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Invoke-AutoKSelection.ps1')
}

Describe "Invoke-AutoKSelection" {
    Context "When given well-separated clusters" {
        BeforeAll {
            # Three clearly separated clusters
            $script:arrVectorRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'a3'; Vector = [double[]]@(0.2, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(5.0, 5.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(5.1, 5.1) }
                [pscustomobject]@{ PrincipalKey = 'b3'; Vector = [double[]]@(5.2, 5.0) }
                [pscustomobject]@{ PrincipalKey = 'c1'; Vector = [double[]]@(10.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'c2'; Vector = [double[]]@(10.1, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'c3'; Vector = [double[]]@(10.2, 0.0) }
            )
        }

        It "Returns a RecommendedK value" {
            # Act
            $objResult = Invoke-AutoKSelection -VectorRows $script:arrVectorRows -MinK 2 -MaxK 5

            # Assert
            $objResult.RecommendedK | Should -BeGreaterOrEqual 2
            $objResult.RecommendedK | Should -BeLessOrEqual 5
        }

        It "Returns a BestModel with assignments" {
            # Act
            $objResult = Invoke-AutoKSelection -VectorRows $script:arrVectorRows -MinK 2 -MaxK 5

            # Assert
            $objResult.BestModel | Should -Not -BeNullOrEmpty
            $objResult.BestModel.Assignments.Count | Should -Be 9
        }

        It "Returns candidates for all evaluated K values" {
            # Act
            $objResult = Invoke-AutoKSelection -VectorRows $script:arrVectorRows -MinK 2 -MaxK 5

            # Assert - should have 4 candidates (K=2,3,4,5)
            $objResult.Candidates.Count | Should -Be 4
        }

        It "Candidates include composite rank scores" {
            # Act
            $objResult = Invoke-AutoKSelection -VectorRows $script:arrVectorRows -MinK 2 -MaxK 5

            # Assert
            foreach ($objCandidate in $objResult.Candidates) {
                $objCandidate.CompositeRank | Should -BeGreaterThan 0
            }
        }

        It "Candidates include all metric columns" {
            # Act
            $objResult = Invoke-AutoKSelection -VectorRows $script:arrVectorRows -MinK 2 -MaxK 4

            # Assert
            $objFirst = $objResult.Candidates[0]
            $objFirst.PSObject.Properties.Name | Should -Contain 'SSE'
            $objFirst.PSObject.Properties.Name | Should -Contain 'Silhouette'
            $objFirst.PSObject.Properties.Name | Should -Contain 'DaviesBouldin'
            $objFirst.PSObject.Properties.Name | Should -Contain 'CalinskiHarabasz'
            $objFirst.PSObject.Properties.Name | Should -Contain 'WCSSSecondDeriv'
            $objFirst.PSObject.Properties.Name | Should -Contain 'CompositeRank'
        }
    }

    Context "When MinK equals MaxK" {
        It "Returns the only K evaluated" {
            # Arrange
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a'; Vector = [double[]]@(1.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b'; Vector = [double[]]@(0.0, 1.0) }
                [pscustomobject]@{ PrincipalKey = 'c'; Vector = [double[]]@(1.0, 1.0) }
            )

            # Act
            $objResult = Invoke-AutoKSelection -VectorRows $arrRows -MinK 2 -MaxK 2

            # Assert
            $objResult.RecommendedK | Should -Be 2
            $objResult.Candidates.Count | Should -Be 1
        }
    }

    Context "When MinK exceeds MaxK after clamping" {
        It "Throws an error" {
            # Arrange - only 2 points, MinK=3
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a'; Vector = [double[]]@(1.0) }
                [pscustomobject]@{ PrincipalKey = 'b'; Vector = [double[]]@(2.0) }
            )

            # Act / Assert
            { Invoke-AutoKSelection -VectorRows $arrRows -MinK 3 -MaxK 5 } | Should -Throw
        }
    }

    Context "When composite rank is deterministic" {
        It "Returns the same result with the same seed" {
            # Arrange
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(5.0, 5.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(5.1, 5.0) }
                [pscustomobject]@{ PrincipalKey = 'c1'; Vector = [double[]]@(10.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'c2'; Vector = [double[]]@(10.1, 0.0) }
            )

            # Act
            $objResult1 = Invoke-AutoKSelection -VectorRows $arrRows -MinK 2 -MaxK 4 -Seed 42
            $objResult2 = Invoke-AutoKSelection -VectorRows $arrRows -MinK 2 -MaxK 4 -Seed 42

            # Assert
            $objResult1.RecommendedK | Should -Be $objResult2.RecommendedK
        }
    }

    Context "When candidates are sorted by K" {
        It "Returns candidates in ascending K order" {
            # Arrange
            $arrRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(5.0, 5.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(5.1, 5.0) }
            )

            # Act
            $objResult = Invoke-AutoKSelection -VectorRows $arrRows -MinK 2 -MaxK 4

            # Assert
            for ($intIdx = 1; $intIdx -lt $objResult.Candidates.Count; $intIdx++) {
                $objResult.Candidates[$intIdx].K | Should -BeGreaterThan $objResult.Candidates[$intIdx - 1].K
            }
        }
    }

    Context "When verifying output contract" {
        BeforeAll {
            # Arrange - well-separated clusters for reliable output
            $script:arrContractRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'a3'; Vector = [double[]]@(0.2, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(5.0, 5.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(5.1, 5.1) }
                [pscustomobject]@{ PrincipalKey = 'b3'; Vector = [double[]]@(5.2, 5.0) }
            )

            # Act
            $script:objResult = Invoke-AutoKSelection -VectorRows $script:arrContractRows -MinK 2 -MaxK 4
        }

        It "Returns a pscustomobject with RecommendedK, BestModel, and Candidates properties" {
            # Assert
            $arrPropertyNames = @($script:objResult.PSObject.Properties.Name)
            $arrPropertyNames | Should -Contain 'RecommendedK'
            $arrPropertyNames | Should -Contain 'BestModel'
            $arrPropertyNames | Should -Contain 'Candidates'
            $script:objResult.RecommendedK | Should -Not -BeNullOrEmpty
            $script:objResult.BestModel | Should -Not -BeNullOrEmpty
            $script:objResult.Candidates | Should -Not -BeNullOrEmpty
        }
    }

    Context "When MaxK is 0 (auto-calculated)" {
        BeforeAll {
            # Arrange - 9 data points in 3 well-separated clusters of 3 each
            $script:arrAutoMaxKRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'a3'; Vector = [double[]]@(0.2, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(5.0, 5.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(5.1, 5.1) }
                [pscustomobject]@{ PrincipalKey = 'b3'; Vector = [double[]]@(5.2, 5.0) }
                [pscustomobject]@{ PrincipalKey = 'c1'; Vector = [double[]]@(10.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'c2'; Vector = [double[]]@(10.1, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'c3'; Vector = [double[]]@(10.2, 0.0) }
            )

            # Act
            # For N=9: Ceiling(Sqrt(9) * 1.2) = Ceiling(3.6) = 4
            # With MinK=2 (default), candidates = K=2,3,4 => 3 candidates
            $script:objAutoResult = Invoke-AutoKSelection -VectorRows $script:arrAutoMaxKRows -MaxK 0
        }

        It "Produces the expected number of candidates from auto-calculated MaxK" {
            # Assert
            $intExpectedMaxK = [int][Math]::Ceiling([Math]::Sqrt(9) * 1.2) # = 4
            $intExpectedCandidateCount = $intExpectedMaxK - 2 + 1 # = 3 (K=2,3,4)
            $script:objAutoResult.Candidates.Count | Should -Be $intExpectedCandidateCount
        }
    }

    Context "When auto-calculating MaxK for a small dataset" {
        BeforeAll {
            # Arrange - 3 data points
            $script:arrSmallRows = @(
                [pscustomobject]@{ PrincipalKey = 'x1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'x2'; Vector = [double[]]@(5.0, 5.0) }
                [pscustomobject]@{ PrincipalKey = 'x3'; Vector = [double[]]@(10.0, 0.0) }
            )

            # Act
            # For N=3: Ceiling(Sqrt(3) * 1.2) = Ceiling(2.078) = 3
            # With MinK=2 (default), candidates = K=2,3 => 2 candidates
            $script:objSmallResult = Invoke-AutoKSelection -VectorRows $script:arrSmallRows -MaxK 0
        }

        It "Produces the expected candidate range for a small dataset" {
            # Assert
            $intExpectedMaxK = [int][Math]::Ceiling([Math]::Sqrt(3) * 1.2) # = 3
            $intExpectedCandidateCount = $intExpectedMaxK - 2 + 1 # = 2 (K=2,3)
            $script:objSmallResult.Candidates.Count | Should -Be $intExpectedCandidateCount
        }
    }

    Context "When explicitly provided MaxK exceeds N" {
        BeforeAll {
            # Arrange - 5 data points in 2 clusters
            $script:arrClampRows = @(
                [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.1) }
                [pscustomobject]@{ PrincipalKey = 'a3'; Vector = [double[]]@(0.2, 0.0) }
                [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(5.0, 5.0) }
                [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(5.1, 5.1) }
            )

            # Act
            # MaxK=10 exceeds N=5, so MaxK is clamped to 5
            # With MinK=2 (default), candidates = K=2,3,4,5 => 4 candidates
            $script:objClampResult = Invoke-AutoKSelection -VectorRows $script:arrClampRows -MaxK 10
        }

        It "Clamps MaxK to N and produces the expected candidate count" {
            # Assert
            $intExpectedCandidateCount = 5 - 2 + 1 # = 4 (K=2,3,4,5)
            $script:objClampResult.Candidates.Count | Should -Be $intExpectedCandidateCount
        }
    }
}
