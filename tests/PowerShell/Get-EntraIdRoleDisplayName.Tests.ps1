BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'

    . (Join-Path -Path $strSrcPath -ChildPath 'Get-EntraIdRoleDisplayName.ps1')
}

Describe "Get-EntraIdRoleDisplayName" {
    Context "When ResourceActions is empty or null" {
        It "Returns fallback name for empty array" {
            # Arrange / Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions @() -ClusterId 5

            # Assert
            $strResult | Should -Be 'GloryRole-EntraCluster-5'
        }

        It "Returns fallback name with custom prefix for empty array" {
            # Arrange / Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions @() -ClusterId 3 -Prefix 'MyPrefix'

            # Assert
            $strResult | Should -Be 'MyPrefix-EntraCluster-3'
        }
    }

    Context "When ResourceActions contains single resource type" {
        It "Generates User Manager for user-only actions" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/users/create'
                'microsoft.directory/users/delete'
                'microsoft.directory/users/basic/update'
                'microsoft.directory/users/password/update'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 0

            # Assert
            $strResult | Should -Be 'GloryRole-User Administrator'
        }

        It "Generates Group Manager for group-only update actions" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/groups/members/update'
                'microsoft.directory/groups/basic/update'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 1

            # Assert
            $strResult | Should -Be 'GloryRole-Group Manager'
        }

        It "Generates Device Administrator for device CRUD actions" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/devices/create'
                'microsoft.directory/devices/delete'
                'microsoft.directory/devices/basic/update'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 2

            # Assert
            $strResult | Should -Be 'GloryRole-Device Administrator'
        }
    }

    Context "When ResourceActions contains multiple resource types" {
        It "Generates combined name for user and group actions" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/users/create'
                'microsoft.directory/users/delete'
                'microsoft.directory/users/basic/update'
                'microsoft.directory/groups/members/update'
                'microsoft.directory/groups/create'
                'microsoft.directory/groups/delete'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 0

            # Assert
            $strResult | Should -Be 'GloryRole-User & Group Administrator'
        }

        It "Generates combined name for application and service principal" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/applications/create'
                'microsoft.directory/applications/delete'
                'microsoft.directory/servicePrincipals/create'
                'microsoft.directory/servicePrincipals/delete'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 0

            # Assert
            $strResult | Should -Be 'GloryRole-Application & Service Principal Administrator'
        }

        It "Limits to top 3 resource types" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/users/create'
                'microsoft.directory/groups/create'
                'microsoft.directory/applications/create'
                'microsoft.directory/devices/create'
                'microsoft.directory/policies/create'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 0

            # Assert
            # Users, Groups, Applications are top 3 by priority
            $strResult | Should -BeLike 'GloryRole-User & Group & Application*'
        }
    }

    Context "When suffix is determined by action verbs" {
        It "Uses Administrator when create and delete are present" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/users/create'
                'microsoft.directory/users/delete'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 0

            # Assert
            $strResult | Should -Match 'Administrator$'
        }

        It "Uses Manager when only update is present" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/users/basic/update'
                'microsoft.directory/users/password/update'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 0

            # Assert
            $strResult | Should -Match 'Manager$'
        }

        It "Uses Administrator for allTasks actions" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/administrativeUnits/allProperties/allTasks'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 0

            # Assert
            $strResult | Should -Match 'Administrator$'
        }
    }

    Context "When custom prefix is provided" {
        It "Applies custom prefix to descriptive name" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/users/basic/update'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 0 -Prefix 'CustomRole'

            # Assert
            $strResult | Should -BeLike 'CustomRole-User*'
        }
    }

    Context "When actions include role management types" {
        It "Generates Role Assignment Manager for role assignment actions" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/roleAssignments/allProperties/update'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 5

            # Assert
            $strResult | Should -Be 'GloryRole-Role Assignment Manager'
        }
    }

    Context "When actions include conditional access" {
        It "Generates Conditional Access Administrator" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/conditionalAccessPolicies/create'
                'microsoft.directory/conditionalAccessPolicies/basic/update'
                'microsoft.directory/conditionalAccessPolicies/delete'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 0

            # Assert
            $strResult | Should -Be 'GloryRole-Conditional Access Administrator'
        }
    }

    Context "When actions contain unrecognized resource types" {
        It "Returns fallback when all actions are unrecognized" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/unknownResource/basic/update'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 7

            # Assert
            $strResult | Should -Be 'GloryRole-EntraCluster-7'
        }

        It "Ignores unrecognized types and uses recognized ones" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/users/basic/update'
                'microsoft.directory/unknownResource/basic/update'
            )

            # Act
            $strResult = Get-EntraIdRoleDisplayName -ResourceActions $arrActions -ClusterId 0

            # Assert
            $strResult | Should -Be 'GloryRole-User Manager'
        }
    }
}
