BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-ActionStatFromCount.ps1')
}

Describe "Get-ActionStatFromCount" {
    Context "When given valid multi-action input" {
        It "Returns correct statistics for multiple actions and principals" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-a'; Count = 10.0 }
                [pscustomobject]@{ PrincipalKey = 'user2'; Action = 'action-a'; Count = 20.0 }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-b'; Count = 5.0 }
            )

            # Act
            $arrResult = @(Get-ActionStatFromCount -Counts $arrCounts)

            # Assert
            $arrResult.Count | Should -Be 2
            $objActionA = $arrResult | Where-Object { $_.Action -eq 'action-a' }
            $objActionA.TotalCount | Should -Be 30.0
            $objActionA.DistinctPrincipals | Should -Be 2
            $objActionB = $arrResult | Where-Object { $_.Action -eq 'action-b' }
            $objActionB.TotalCount | Should -Be 5.0
            $objActionB.DistinctPrincipals | Should -Be 1
        }
    }

    Context "When principals are duplicated for the same action" {
        It "Deduplicates principals and sums counts" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-a'; Count = 10.0 }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-a'; Count = 15.0 }
            )

            # Act
            $arrResult = @(Get-ActionStatFromCount -Counts $arrCounts)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].DistinctPrincipals | Should -Be 1
            $arrResult[0].TotalCount | Should -Be 25.0
        }
    }

    Context "When given single-element input" {
        It "Returns exactly one result for a single input row" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-a'; Count = 7.0 }
            )

            # Act
            $arrResult = @(Get-ActionStatFromCount -Counts $arrCounts)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].Action | Should -Be 'action-a'
            $arrResult[0].TotalCount | Should -Be 7.0
            $arrResult[0].DistinctPrincipals | Should -Be 1
        }
    }

    Context "When verifying output schema" {
        It "Each output object has exactly Action, TotalCount, and DistinctPrincipals properties" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-a'; Count = 3.0 }
            )

            # Act
            $arrResult = @(Get-ActionStatFromCount -Counts $arrCounts)

            # Assert
            $arrPropertyNames = @($arrResult[0].PSObject.Properties.Name)
            $arrPropertyNames | Should -Contain 'Action'
            $arrPropertyNames | Should -Contain 'TotalCount'
            $arrPropertyNames | Should -Contain 'DistinctPrincipals'
            $arrPropertyNames.Count | Should -Be 3
        }
    }

    Context "When verifying 0-1-many pipeline contract" {
        It "Returns an empty array when given empty input" {
            # Arrange / Act
            $arrResult = @(Get-ActionStatFromCount -Counts @() -ErrorAction SilentlyContinue)

            # Assert
            $arrResult.Count | Should -Be 0
        }

        It "Returns a single-element array when one result is produced" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-a'; Count = 4.0 }
            )

            # Act
            $arrResult = @(Get-ActionStatFromCount -Counts $arrCounts)

            # Assert
            $arrResult.Count | Should -Be 1
        }

        It "Returns a multi-element array when multiple results are produced" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-a'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-b'; Count = 2.0 }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-c'; Count = 3.0 }
            )

            # Act
            $arrResult = @(Get-ActionStatFromCount -Counts $arrCounts)

            # Assert
            $arrResult.Count | Should -Be 3
        }
    }

    Context "When given malformed input" {
        It "Emits a non-terminating error for a row missing the Count property" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-a' }
            )

            # Act
            $arrResult = @(Get-ActionStatFromCount -Counts $arrCounts -ErrorVariable err -ErrorAction SilentlyContinue)

            # Assert
            $err.Count | Should -BeGreaterOrEqual 1
        }

        It "Emits a non-terminating error for a row with a non-numeric Count value" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-a'; Count = 'notanumber' }
            )

            # Act
            $arrResult = @(Get-ActionStatFromCount -Counts $arrCounts -ErrorVariable err -ErrorAction SilentlyContinue)

            # Assert
            $err.Count | Should -BeGreaterOrEqual 1
        }
    }

    Context "When -ErrorAction Stop is used with malformed input" {
        It "Throws a terminating error for a row missing a required property" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'action-a' }
            )

            # Act / Assert
            { Get-ActionStatFromCount -Counts $arrCounts -ErrorAction Stop } | Should -Throw
        }
    }
}
