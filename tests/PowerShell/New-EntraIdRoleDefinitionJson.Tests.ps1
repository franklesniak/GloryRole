BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'New-EntraIdRoleDefinitionJson.ps1')
}

Describe "New-EntraIdRoleDefinitionJson" {
    Context "When generating an Entra ID role definition" {
        It "Produces valid JSON" {
            # Arrange
            $arrActions = @('microsoft.directory/groups/members/update', 'microsoft.directory/users/create')

            # Act
            $strJson = New-EntraIdRoleDefinitionJson `
                -RoleName 'Test Entra Role' `
                -Description 'A test Entra ID role' `
                -ResourceActions $arrActions

            # Assert - should parse without error
            $objParsed = $strJson | ConvertFrom-Json
            $objParsed | Should -Not -BeNullOrEmpty
        }

        It "Contains required properties in unifiedRoleDefinition format" {
            # Arrange / Act
            $strJson = New-EntraIdRoleDefinitionJson `
                -RoleName 'MyEntraRole' `
                -Description 'Desc' `
                -ResourceActions @('microsoft.directory/groups/members/update')

            $objParsed = $strJson | ConvertFrom-Json

            # Assert
            $objParsed.displayName | Should -Be 'MyEntraRole'
            $objParsed.description | Should -Be 'Desc'
            $objParsed.isEnabled | Should -BeTrue
            $objParsed.rolePermissions | Should -Not -BeNullOrEmpty
        }

        It "Contains rolePermissions with allowedResourceActions" {
            # Arrange / Act
            $strJson = New-EntraIdRoleDefinitionJson `
                -RoleName 'R' `
                -Description 'D' `
                -ResourceActions @('microsoft.directory/users/create')

            $objParsed = $strJson | ConvertFrom-Json

            # Assert
            $objParsed.rolePermissions.Count | Should -Be 1
            $objParsed.rolePermissions[0].allowedResourceActions | Should -Contain 'microsoft.directory/users/create'
        }

        It "Correctly serializes multiple resource actions" {
            # Arrange
            $arrActions = @(
                'microsoft.directory/groups/members/update',
                'microsoft.directory/users/create',
                'microsoft.directory/users/password/update'
            )

            # Act
            $strJson = New-EntraIdRoleDefinitionJson `
                -RoleName 'MultiActionRole' `
                -Description 'Multiple actions' `
                -ResourceActions $arrActions

            $objParsed = $strJson | ConvertFrom-Json

            # Assert
            $objParsed.rolePermissions[0].allowedResourceActions.Count | Should -Be 3
            $objParsed.rolePermissions[0].allowedResourceActions | Should -Contain 'microsoft.directory/groups/members/update'
            $objParsed.rolePermissions[0].allowedResourceActions | Should -Contain 'microsoft.directory/users/create'
            $objParsed.rolePermissions[0].allowedResourceActions | Should -Contain 'microsoft.directory/users/password/update'
        }

        It "Sets isEnabled to false when specified" {
            # Arrange / Act
            $strJson = New-EntraIdRoleDefinitionJson `
                -RoleName 'DisabledRole' `
                -Description 'Disabled' `
                -ResourceActions @('microsoft.directory/users/create') `
                -IsEnabled $false

            $objParsed = $strJson | ConvertFrom-Json

            # Assert
            $objParsed.isEnabled | Should -BeFalse
        }

        It "Includes condition property in rolePermissions" {
            # Arrange / Act
            $strJson = New-EntraIdRoleDefinitionJson `
                -RoleName 'R' `
                -Description 'D' `
                -ResourceActions @('microsoft.directory/users/create')

            $objParsed = $strJson | ConvertFrom-Json

            # Assert - condition should be present (null value)
            $objParsed.rolePermissions[0].PSObject.Properties.Name | Should -Contain 'condition'
        }
    }
}
