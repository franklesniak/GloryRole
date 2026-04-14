BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-ClusterActionSet.ps1')
}

Describe "Get-ClusterActionSet" {
    Context "Normal mapping" {
        It "Returns single cluster with sorted, deduplicated actions" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'write'; Count = 3 }
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 5 }
            )
            $hashAssignments = @{ 'userA' = 0 }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].ClusterId | Should -Be 0
            $arrResult[0].Actions.Count | Should -Be 2
            $arrResult[0].Actions[0] | Should -Be 'read'
            $arrResult[0].Actions[1] | Should -Be 'write'
        }
    }

    Context "Multi-cluster output" {
        It "Returns clusters sorted by ClusterId ascending" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'userB'; Action = 'write'; Count = 2 }
                [pscustomobject]@{ PrincipalKey = 'userC'; Action = 'delete'; Count = 1 }
            )
            $hashAssignments = @{
                'userA' = 2
                'userB' = 0
                'userC' = 1
            }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult.Count | Should -Be 3
            $arrResult[0].ClusterId | Should -Be 0
            $arrResult[1].ClusterId | Should -Be 1
            $arrResult[2].ClusterId | Should -Be 2
        }
    }

    Context "Deduplication" {
        It "Two principals in the same cluster with the same action produce a single action entry" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'userB'; Action = 'read'; Count = 3 }
            )
            $hashAssignments = @{
                'userA' = 0
                'userB' = 0
            }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].Actions.Count | Should -Be 1
            $arrResult[0].Actions[0] | Should -Be 'read'
        }
    }

    Context "Skipped principals" {
        It "Excludes principals not present in AssignmentsMap" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'unknownUser'; Action = 'write'; Count = 2 }
            )
            $hashAssignments = @{ 'userA' = 0 }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].ClusterId | Should -Be 0
            $arrResult[0].Actions.Count | Should -Be 1
            $arrResult[0].Actions[0] | Should -Be 'read'
        }
    }

    Context "No matches" {
        It "Returns empty output when all principals are missing from AssignmentsMap" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'unknownA'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'unknownB'; Action = 'write'; Count = 2 }
            )
            $hashAssignments = @{ 'userA' = 0 }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult.Count | Should -Be 0
        }
    }

    Context "Empty AssignmentsMap" {
        It "Returns empty output when AssignmentsMap is empty" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
            )
            $hashAssignments = @{}

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult.Count | Should -Be 0
        }
    }

    Context "Principals output" {
        It "Returns sorted principals for a single cluster" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userB'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'write'; Count = 2 }
            )
            $hashAssignments = @{
                'userA' = 0
                'userB' = 0
            }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].Principals.Count | Should -Be 2
            $arrResult[0].Principals[0] | Should -Be 'userA'
            $arrResult[0].Principals[1] | Should -Be 'userB'
        }

        It "Returns deduplicated principals when a principal has multiple actions" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'write'; Count = 3 }
            )
            $hashAssignments = @{ 'userA' = 0 }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult[0].Principals.Count | Should -Be 1
            $arrResult[0].Principals[0] | Should -Be 'userA'
        }

        It "Assigns principals to the correct clusters" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'userB'; Action = 'write'; Count = 2 }
                [pscustomobject]@{ PrincipalKey = 'userC'; Action = 'delete'; Count = 1 }
            )
            $hashAssignments = @{
                'userA' = 0
                'userB' = 1
                'userC' = 0
            }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult.Count | Should -Be 2
            $arrResult[0].ClusterId | Should -Be 0
            $arrResult[0].Principals.Count | Should -Be 2
            $arrResult[0].Principals | Should -Contain 'userA'
            $arrResult[0].Principals | Should -Contain 'userC'
            $arrResult[1].ClusterId | Should -Be 1
            $arrResult[1].Principals.Count | Should -Be 1
            $arrResult[1].Principals[0] | Should -Be 'userB'
        }

        It "Excludes skipped principals from Principals output" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'unknownUser'; Action = 'write'; Count = 2 }
            )
            $hashAssignments = @{ 'userA' = 0 }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult[0].Principals.Count | Should -Be 1
            $arrResult[0].Principals[0] | Should -Be 'userA'
        }
    }

    Context "Output property types" {
        It "ClusterId is [int], Actions is [string[]], and Principals is [string[]]" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
            )
            $hashAssignments = @{ 'userA' = 0 }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult[0].ClusterId | Should -BeOfType [int]
            ($arrResult[0].Actions -is [string[]]) | Should -BeTrue
            ($arrResult[0].Principals -is [string[]]) | Should -BeTrue
        }
    }

    Context "0-1-many pipeline contract" {
        It "Zero-output case returns empty array when wrapped in @()" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'missing'; Action = 'read'; Count = 1 }
            )
            $hashAssignments = @{ 'other' = 0 }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult.Count | Should -Be 0
        }

        It "Single-output case returns array with one element when wrapped in @()" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
            )
            $hashAssignments = @{ 'userA' = 0 }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult.Count | Should -Be 1
        }

        It "Multi-output case returns array with expected number of elements" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'userB'; Action = 'write'; Count = 2 }
                [pscustomobject]@{ PrincipalKey = 'userC'; Action = 'delete'; Count = 1 }
            )
            $hashAssignments = @{
                'userA' = 0
                'userB' = 1
                'userC' = 2
            }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult.Count | Should -Be 3
        }
    }
}
