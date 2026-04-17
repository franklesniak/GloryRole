BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'

    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-EntraIdResourceAction.ps1')
}

Describe "ConvertTo-EntraIdResourceAction" {
    Context "When activity display name is null or empty" {
        It "Returns null for empty string" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName '' -Category 'GroupManagement'

            # Assert
            $strResult | Should -Be $null
        }

        It "Returns null for whitespace-only string" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName '   ' -Category 'GroupManagement'

            # Assert
            $strResult | Should -Be $null
        }
    }

    Context "When activity has a known mapping" {
        It "Maps 'Add member to group' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add member to group' -Category 'GroupManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/groups/members/update'
        }

        It "Maps 'Add user' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add user' -Category 'UserManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/users/create'
        }

        It "Maps 'Reset user password' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Reset user password' -Category 'UserManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/users/password/update'
        }

        It "Maps 'Add member to role' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add member to role' -Category 'RoleManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/roleAssignments/allProperties/update'
        }

        It "Maps 'Add application' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add application' -Category 'ApplicationManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/applications/create'
        }

        It "Maps 'Add conditional access policy' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add conditional access policy' -Category 'Policy'

            # Assert
            $strResult | Should -Be 'microsoft.directory/conditionalAccessPolicies/create'
        }

        It "Is case-insensitive for activity display name" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'ADD MEMBER TO GROUP' -Category 'GroupManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/groups/members/update'
        }

        It "Trims whitespace from activity display name" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName '  Add member to group  ' -Category 'GroupManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/groups/members/update'
        }
    }

    Context "When activity is not in the mapping table" {
        It "Returns null for an unmapped activity" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Some New Activity' -Category 'UserManagement'

            # Assert
            $strResult | Should -Be $null
        }

        It "Returns null when category is empty and activity is unmapped" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'My Activity' -Category ''

            # Assert
            $strResult | Should -Be $null
        }

        It "Returns null for self-service activities" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Self-service password reset flow activity progress' -Category 'UserManagement'

            # Assert
            $strResult | Should -Be $null
        }

        It "Returns null for informational audit events" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'User registered all required security info' -Category 'UserManagement'

            # Assert
            $strResult | Should -Be $null
        }
    }

    Context "When activity is a newly mapped administrative action" {
        It "Maps 'Change user license' to users/assignLicense" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Change user license' -Category 'UserManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/users/assignLicense'
        }

        It "Maps 'Register device' to devices/create" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Register device' -Category 'Device'

            # Assert
            $strResult | Should -Be 'microsoft.directory/devices/create'
        }

        It "Maps 'Unregister device' to devices/delete" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Unregister device' -Category 'Device'

            # Assert
            $strResult | Should -Be 'microsoft.directory/devices/delete'
        }

        It "Maps 'Update password profile' to users/password/update" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Update password profile' -Category 'UserManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/users/password/update'
        }

        It "Maps 'Restore group' to groups/restore" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Restore group' -Category 'GroupManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/groups/restore'
        }

        It "Maps 'Add administrative unit' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add administrative unit' -Category 'DirectoryManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/administrativeUnits/allProperties/allTasks'
        }
    }

    Context "When activity is a comprehensive mapping entry" {
        It "Maps 'Disable account' to users/disable" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Disable account' -Category 'UserManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/users/disable'
        }

        It "Maps 'Enable account' to users/enable" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Enable account' -Category 'UserManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/users/enable'
        }

        It "Maps 'Update user principal name' to users/userPrincipalName/update" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Update user principal name' -Category 'UserManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/users/userPrincipalName/update'
        }

        It "Maps 'Disable service principal' to servicePrincipals/disable" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Disable service principal' -Category 'ApplicationManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/servicePrincipals/disable'
        }

        It "Maps 'Enable service principal' to servicePrincipals/enable" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Enable service principal' -Category 'ApplicationManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/servicePrincipals/enable'
        }

        It "Maps 'Add contact' to contacts/create" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add contact' -Category 'ContactManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/contacts/create'
        }

        It "Maps 'Add connector group' to connectorGroups/create" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add connector group' -Category 'ApplicationManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/connectorGroups/create'
        }

        It "Maps 'Add custom authentication extension' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add custom authentication extension' -Category 'ApplicationManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/customAuthenticationExtensions/allProperties/allTasks'
        }

        It "Maps 'Update cross tenant access policy' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Update cross tenant access policy' -Category 'Policy'

            # Assert
            $strResult | Should -Be 'microsoft.directory/crossTenantAccessPolicy/basic/update'
        }

        It "Maps 'Add identity provider' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add identity provider' -Category 'ApplicationManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/identityProviders/allProperties/allTasks'
        }

        It "Maps 'Add role definition' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add role definition' -Category 'RoleManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/roleDefinitions/allProperties/allTasks'
        }

        It "Maps 'Add owner to service principal' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add owner to service principal' -Category 'ApplicationManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/servicePrincipals/owners/update'
        }

        It "Maps 'Set company branding' correctly" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Set company branding' -Category 'DirectoryManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/loginOrganizationBranding/allProperties/allTasks'
        }

        It "Maps 'Hard delete group' to groups/delete" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Hard delete group' -Category 'GroupManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/groups/delete'
        }

        It "Maps 'Add access package' to entitlementManagement" {
            # Arrange / Act
            $strResult = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add access package' -Category 'EntitlementManagement'

            # Assert
            $strResult | Should -Be 'microsoft.directory/entitlementManagement/allProperties/allTasks'
        }
    }
}
