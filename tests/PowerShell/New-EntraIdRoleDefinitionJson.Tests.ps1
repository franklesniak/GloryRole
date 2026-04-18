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

    Context "When required parameters are empty" {
        It "Fails fast when RoleName is an empty string" {
            {
                New-EntraIdRoleDefinitionJson `
                    -RoleName '' `
                    -Description 'D' `
                    -ResourceActions @('microsoft.directory/users/create')
            } | Should -Throw
        }

        It "Fails fast when Description is an empty string" {
            {
                New-EntraIdRoleDefinitionJson `
                    -RoleName 'R' `
                    -Description '' `
                    -ResourceActions @('microsoft.directory/users/create')
            } | Should -Throw
        }

        It "Fails fast when ResourceActions is an empty array" {
            {
                New-EntraIdRoleDefinitionJson `
                    -RoleName 'R' `
                    -Description 'D' `
                    -ResourceActions @()
            } | Should -Throw
        }
    }

    Context "Defensive validation for accidentally downcased camelCase actions" {
        It "Emits Write-Warning for a downcased oAuth2PermissionGrants segment" {
            # Arrange - deliberately downcased form that would result from
            # accidentally piping through ConvertTo-NormalizedAction
            $arrActions = @('microsoft.directory/oauth2permissiongrants/allproperties/update')

            # Act / Assert - the function should emit a warning
            $arrOutput = New-EntraIdRoleDefinitionJson `
                -RoleName 'WarnTest' `
                -Description 'D' `
                -ResourceActions $arrActions `
                3>&1

            # The 3>&1 redirect merges the warning stream into the
            # output stream. At least one warning should mention the
            # downcased segment. An action with multiple downcased
            # segments can produce multiple warnings, so filter the
            # collection rather than indexing [0] (which would be
            # sensitive to $arrKnownCamelCaseSegments ordering).
            $arrWarnings = @($arrOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
            $arrWarnings.Count | Should -BeGreaterThan 0
            $arrMatchingWarnings = @($arrWarnings | Where-Object { $_.Message -like '*oauth2permissiongrants*' })
            $arrMatchingWarnings | Should -Not -BeNullOrEmpty
        }

        It "Emits Write-Warning for a downcased servicePrincipals segment" {
            # Arrange
            $arrActions = @('microsoft.directory/serviceprincipals/standard/read')

            # Act
            $arrOutput = New-EntraIdRoleDefinitionJson `
                -RoleName 'WarnTest' `
                -Description 'D' `
                -ResourceActions $arrActions `
                3>&1

            # Assert - filter by substring (order-independent)
            $arrWarnings = @($arrOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
            $arrMatchingWarnings = @($arrWarnings | Where-Object { $_.Message -like '*serviceprincipals*' })
            $arrMatchingWarnings | Should -Not -BeNullOrEmpty
        }

        It "Emits Write-Warning when only a nested segment (allProperties) is downcased on a naturally-lowercase resource" {
            # Arrange - 'domains' is naturally lowercase and therefore
            # must not warn on its own, but 'allProperties' is camelCase
            # and must be flagged when it appears as 'allproperties'.
            # This guards against the failure mode where a caller
            # correctly preserves the resource-type segment but routes
            # the action through a lowercase normalizer that collapses
            # the nested segments.
            $arrActions = @('microsoft.directory/domains/allproperties/update')

            # Act
            $arrOutput = New-EntraIdRoleDefinitionJson `
                -RoleName 'WarnTest' `
                -Description 'D' `
                -ResourceActions $arrActions `
                3>&1

            # Assert - at least one warning mentions 'allproperties'
            $arrWarnings = @($arrOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
            $arrMatchingWarnings = @($arrWarnings | Where-Object { $_.Message -like '*allproperties*' })
            $arrMatchingWarnings | Should -Not -BeNullOrEmpty
        }

        It "Does not emit Write-Warning for correctly cased actions" {
            # Arrange - properly cased camelCase actions
            $arrActions = @(
                'microsoft.directory/oAuth2PermissionGrants/allProperties/update'
                'microsoft.directory/servicePrincipals/standard/read'
                'microsoft.directory/conditionalAccessPolicies/create'
            )

            # Act
            $arrOutput = New-EntraIdRoleDefinitionJson `
                -RoleName 'NoWarnTest' `
                -Description 'D' `
                -ResourceActions $arrActions `
                3>&1

            # Assert - no warnings should be emitted
            $arrWarnings = @($arrOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
            $arrWarnings.Count | Should -Be 0
        }

        It "Does not emit Write-Warning for all-lowercase segments that are naturally lowercase" {
            # Arrange - segments like 'users', 'groups', 'applications' are
            # already all-lowercase in their canonical form
            $arrActions = @(
                'microsoft.directory/users/basic/update'
                'microsoft.directory/groups/members/update'
                'microsoft.directory/applications/create'
            )

            # Act
            $arrOutput = New-EntraIdRoleDefinitionJson `
                -RoleName 'LowercaseNatural' `
                -Description 'D' `
                -ResourceActions $arrActions `
                3>&1

            # Assert
            $arrWarnings = @($arrOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
            $arrWarnings.Count | Should -Be 0
        }

        It "Still produces valid JSON even when warnings are emitted" {
            # Arrange - downcased action that triggers a warning
            $arrActions = @('microsoft.directory/oauth2permissiongrants/allproperties/update')

            # Act - capture only the success stream (suppress warnings)
            $strJson = New-EntraIdRoleDefinitionJson `
                -RoleName 'StillValid' `
                -Description 'D' `
                -ResourceActions $arrActions `
                -WarningAction SilentlyContinue

            # Assert - output is valid JSON
            $objParsed = $strJson | ConvertFrom-Json
            $objParsed | Should -Not -BeNullOrEmpty
            $objParsed.displayName | Should -Be 'StillValid'
            $objParsed.rolePermissions[0].allowedResourceActions | Should -Contain 'microsoft.directory/oauth2permissiongrants/allproperties/update'
        }

        It "Preserves camelCase actions verbatim in the JSON output" {
            # Arrange - correctly cased Entra ID actions
            $arrActions = @(
                'microsoft.directory/oAuth2PermissionGrants/allProperties/update'
                'microsoft.directory/servicePrincipals/standard/read'
            )

            # Act
            $strJson = New-EntraIdRoleDefinitionJson `
                -RoleName 'CamelCaseRole' `
                -Description 'Preserves casing' `
                -ResourceActions $arrActions

            $objParsed = $strJson | ConvertFrom-Json

            # Assert - case-sensitive containment
            $arrEmittedActions = @($objParsed.rolePermissions[0].allowedResourceActions)
            $arrEmittedActions | Should -Not -BeNullOrEmpty
            ($arrEmittedActions -ccontains 'microsoft.directory/oAuth2PermissionGrants/allProperties/update') | Should -BeTrue
            ($arrEmittedActions -ccontains 'microsoft.directory/servicePrincipals/standard/read') | Should -BeTrue
            # Downcased forms MUST be absent
            ($arrEmittedActions -ccontains 'microsoft.directory/oauth2permissiongrants/allproperties/update') | Should -BeFalse
            ($arrEmittedActions -ccontains 'microsoft.directory/serviceprincipals/standard/read') | Should -BeFalse
        }
    }
}
