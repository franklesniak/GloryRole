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
            $arrResult[0].Principals | Should -Not -BeNullOrEmpty
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
            $arrResult.Count | Should -Be 1
            $arrResult[0].Principals | Should -Not -BeNullOrEmpty
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
            $arrResult[0].Principals | Should -Not -BeNullOrEmpty
            $arrResult[0].Principals.Count | Should -Be 2
            $arrResult[0].Principals | Should -Contain 'userA'
            $arrResult[0].Principals | Should -Contain 'userC'
            $arrResult[1].ClusterId | Should -Be 1
            $arrResult[1].Principals | Should -Not -BeNullOrEmpty
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
            $arrResult.Count | Should -Be 1
            $arrResult[0].Principals | Should -Not -BeNullOrEmpty
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
            $arrResult.Count | Should -Be 1
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

    Context "PrincipalDisplayNameMap - with map" {
        It "Adds PrincipalDisplayNames property when map is provided" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'guid-1'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'guid-2'; Action = 'write'; Count = 2 }
            )
            $hashAssignments = @{
                'guid-1' = 0
                'guid-2' = 0
            }
            $hashDisplayNames = @{
                'guid-1' = 'alice@contoso.com'
                'guid-2' = 'bob@contoso.com'
            }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments -PrincipalDisplayNameMap $hashDisplayNames)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].PSObject.Properties['PrincipalDisplayNames'] | Should -Not -BeNullOrEmpty
            $arrResult[0].PrincipalDisplayNames.Count | Should -Be 2
            $arrResult[0].PrincipalDisplayNames | Should -Contain 'alice@contoso.com'
            $arrResult[0].PrincipalDisplayNames | Should -Contain 'bob@contoso.com'
        }

        It "Returns sorted PrincipalDisplayNames" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'guid-z'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'guid-a'; Action = 'write'; Count = 2 }
            )
            $hashAssignments = @{
                'guid-z' = 0
                'guid-a' = 0
            }
            $hashDisplayNames = @{
                'guid-z' = 'zara@contoso.com'
                'guid-a' = 'alice@contoso.com'
            }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments -PrincipalDisplayNameMap $hashDisplayNames)

            # Assert
            $arrResult[0].PrincipalDisplayNames[0] | Should -Be 'alice@contoso.com'
            $arrResult[0].PrincipalDisplayNames[1] | Should -Be 'zara@contoso.com'
        }

        It "Falls back to PrincipalKey when principal is not in the map" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'guid-1'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'guid-2'; Action = 'write'; Count = 2 }
            )
            $hashAssignments = @{
                'guid-1' = 0
                'guid-2' = 0
            }
            $hashDisplayNames = @{
                'guid-1' = 'alice@contoso.com'
                # guid-2 intentionally missing
            }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments -PrincipalDisplayNameMap $hashDisplayNames)

            # Assert
            $arrResult[0].PrincipalDisplayNames | Should -Contain 'alice@contoso.com'
            $arrResult[0].PrincipalDisplayNames | Should -Contain 'guid-2'
        }

        It "PrincipalDisplayNames is [string[]]" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'guid-1'; Action = 'read'; Count = 1 }
            )
            $hashAssignments = @{ 'guid-1' = 0 }
            $hashDisplayNames = @{ 'guid-1' = 'alice@contoso.com' }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments -PrincipalDisplayNameMap $hashDisplayNames)

            # Assert
            ($arrResult[0].PrincipalDisplayNames -is [string[]]) | Should -BeTrue
        }
    }

    Context "PrincipalDisplayNameMap - without map" {
        It "Does not add PrincipalDisplayNames property when map is not provided" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
            )
            $hashAssignments = @{ 'userA' = 0 }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert
            $arrResult[0].PSObject.Properties['PrincipalDisplayNames'] | Should -BeNullOrEmpty
        }

        It "Does not add PrincipalDisplayNames property when map is empty" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
            )
            $hashAssignments = @{ 'userA' = 0 }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments -PrincipalDisplayNameMap @{})

            # Assert
            $arrResult[0].PSObject.Properties['PrincipalDisplayNames'] | Should -BeNullOrEmpty
        }
    }

    Context "PrincipalDisplayNameMap - multi-cluster" {
        It "Each cluster gets its own PrincipalDisplayNames from the shared map" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'guid-1'; Action = 'read'; Count = 1 }
                [pscustomobject]@{ PrincipalKey = 'guid-2'; Action = 'write'; Count = 2 }
                [pscustomobject]@{ PrincipalKey = 'guid-3'; Action = 'delete'; Count = 1 }
            )
            $hashAssignments = @{
                'guid-1' = 0
                'guid-2' = 1
                'guid-3' = 0
            }
            $hashDisplayNames = @{
                'guid-1' = 'alice@contoso.com'
                'guid-2' = 'bob@contoso.com'
                'guid-3' = 'charlie@contoso.com'
            }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments -PrincipalDisplayNameMap $hashDisplayNames)

            # Assert
            $arrResult.Count | Should -Be 2
            $arrResult[0].ClusterId | Should -Be 0
            $arrResult[0].PrincipalDisplayNames.Count | Should -Be 2
            $arrResult[0].PrincipalDisplayNames | Should -Contain 'alice@contoso.com'
            $arrResult[0].PrincipalDisplayNames | Should -Contain 'charlie@contoso.com'
            $arrResult[1].ClusterId | Should -Be 1
            $arrResult[1].PrincipalDisplayNames.Count | Should -Be 1
            $arrResult[1].PrincipalDisplayNames[0] | Should -Be 'bob@contoso.com'
        }
    }

    Context "Entra ID camelCase action preservation" {
        It "Preserves camelCase segments in microsoft.directory/* actions through clustering" {
            # Arrange - Entra ID actions with camelCase segments that must
            # survive clustering without being downcased.
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'admin-001'; Action = 'microsoft.directory/oAuth2PermissionGrants/allProperties/update'; Count = 10 }
                [pscustomobject]@{ PrincipalKey = 'admin-001'; Action = 'microsoft.directory/servicePrincipals/standard/read'; Count = 5 }
                [pscustomobject]@{ PrincipalKey = 'admin-002'; Action = 'microsoft.directory/conditionalAccessPolicies/create'; Count = 3 }
            )
            $hashAssignments = @{
                'admin-001' = 0
                'admin-002' = 1
            }

            # Act
            $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)

            # Assert - camelCase segments are preserved verbatim
            $arrResult | Should -Not -BeNullOrEmpty
            $arrResult.Count | Should -Be 2

            $arrCluster0 = $arrResult | Where-Object { $_.ClusterId -eq 0 }
            $arrCluster0 | Should -Not -BeNullOrEmpty
            $arrCluster0.Actions | Should -Not -BeNullOrEmpty
            $arrCluster0.Actions | Should -Contain 'microsoft.directory/oAuth2PermissionGrants/allProperties/update'
            $arrCluster0.Actions | Should -Contain 'microsoft.directory/servicePrincipals/standard/read'
            # Verify downcased forms are absent (case-sensitive check)
            ($arrCluster0.Actions -ccontains 'microsoft.directory/oauth2permissiongrants/allproperties/update') | Should -BeFalse
            ($arrCluster0.Actions -ccontains 'microsoft.directory/serviceprincipals/standard/read') | Should -BeFalse

            $arrCluster1 = $arrResult | Where-Object { $_.ClusterId -eq 1 }
            $arrCluster1 | Should -Not -BeNullOrEmpty
            $arrCluster1.Actions | Should -Not -BeNullOrEmpty
            $arrCluster1.Actions | Should -Contain 'microsoft.directory/conditionalAccessPolicies/create'
            ($arrCluster1.Actions -ccontains 'microsoft.directory/conditionalaccesspolicies/create') | Should -BeFalse
        }
    }
}
