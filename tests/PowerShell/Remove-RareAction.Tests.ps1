BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-NormalizedAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-ActionStatFromCount.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Remove-RareAction.ps1')
}

Describe "Remove-RareAction" {
    Context "When actions meet thresholds" {
        It "Keeps actions above both thresholds" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-a'; Count = 10.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'action-a'; Count = 10.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-b'; Count = 5.0 }
            )

            # Act
            $objResult = Remove-RareAction -Counts $arrCounts -MinDistinctPrincipals 2 -MinTotalCount 10

            # Assert
            $objResult.Kept.Count | Should -Be 2
            $objResult.Kept[0].Action | Should -Be 'action-a'
        }
    }

    Context "When actions fail thresholds" {
        It "Drops actions below MinDistinctPrincipals" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'rare-action'; Count = 100.0 }
            )

            # Act
            $objResult = Remove-RareAction -Counts $arrCounts -MinDistinctPrincipals 2 -MinTotalCount 1

            # Assert
            $objResult.Kept.Count | Should -Be 0
            $objResult.Dropped.Count | Should -Be 1
        }

        It "Drops actions below MinTotalCount" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'low-count'; Count = 3.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'low-count'; Count = 2.0 }
            )

            # Act
            $objResult = Remove-RareAction -Counts $arrCounts -MinDistinctPrincipals 2 -MinTotalCount 10

            # Assert
            $objResult.Kept.Count | Should -Be 0
            $objResult.Dropped.Count | Should -Be 2
        }
    }

    Context "When Stats are returned" {
        It "Returns action statistics" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'a'; Count = 5.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'a'; Count = 10.0 }
            )

            # Act
            $objResult = Remove-RareAction -Counts $arrCounts -MinDistinctPrincipals 1 -MinTotalCount 1

            # Assert
            $objResult.Stats | Should -Not -BeNullOrEmpty
            $objResult.Stats[0].TotalCount | Should -Be 15.0
            $objResult.Stats[0].DistinctPrincipals | Should -Be 2
        }
    }

    Context "When using default parameter values" {
        It "Applies default thresholds of MinDistinctPrincipals=2 and MinTotalCount=10" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'kept-action'; Count = 6.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'kept-action'; Count = 5.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'dropped-action'; Count = 50.0 }
            )

            # Act
            $objResult = Remove-RareAction -Counts $arrCounts

            # Assert
            $objResult.Kept.Count | Should -Be 2
            $objResult.Kept[0].Action | Should -Be 'kept-action'
            $objResult.Dropped.Count | Should -Be 1
            $objResult.Dropped[0].Action | Should -Be 'dropped-action'
        }
    }

    Context "When verifying output structure" {
        It "Returns a pscustomobject with exactly Kept, Dropped, and Stats properties" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'a'; Count = 1.0 }
            )

            # Act
            $objResult = Remove-RareAction -Counts $arrCounts -MinDistinctPrincipals 1 -MinTotalCount 1

            # Assert
            $objResult -is [pscustomobject] | Should -BeTrue
            $arrPropertyNames = @($objResult.PSObject.Properties.Name)
            $arrPropertyNames | Should -Contain 'Kept'
            $arrPropertyNames | Should -Contain 'Dropped'
            $arrPropertyNames | Should -Contain 'Stats'
            $arrPropertyNames | Should -HaveCount 3
        }
    }

    Context "When all actions fail thresholds" {
        It "Returns empty Kept and all input in Dropped" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'a'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'b'; Count = 2.0 }
            )

            # Act
            $objResult = Remove-RareAction -Counts $arrCounts -MinDistinctPrincipals 100 -MinTotalCount 100000

            # Assert
            $objResult.Kept.Count | Should -Be 0
            $objResult.Dropped.Count | Should -Be 2
        }
    }

    Context "When given empty input" {
        It "Returns empty Kept, Dropped, and Stats arrays" {
            # Arrange
            $arrCounts = @()

            # Act
            $objResult = Remove-RareAction -Counts $arrCounts -MinDistinctPrincipals 1 -MinTotalCount 1

            # Assert
            $objResult.Kept.Count | Should -Be 0
            $objResult.Dropped.Count | Should -Be 0
            $objResult.Stats.Count | Should -Be 0
        }
    }
}
