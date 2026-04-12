BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'New-AzureRoleDefinitionJson.ps1')
}

Describe "New-AzureRoleDefinitionJson" {
    Context "When generating a role definition" {
        It "Produces valid JSON" {
            # Arrange
            $arrActions = @('Microsoft.Compute/*/read', 'Microsoft.Network/*/read')
            $arrScopes = @('/subscriptions/sub-123')

            # Act
            $strJson = New-AzureRoleDefinitionJson `
                -RoleName 'Test Role' `
                -Description 'A test role' `
                -Actions $arrActions `
                -AssignableScopes $arrScopes

            # Assert - should parse without error
            $objParsed = $strJson | ConvertFrom-Json
            $objParsed | Should -Not -BeNullOrEmpty
        }

        It "Contains required properties" {
            # Arrange / Act
            $strJson = New-AzureRoleDefinitionJson `
                -RoleName 'MyRole' `
                -Description 'Desc' `
                -Actions @('a/b/c') `
                -AssignableScopes @('/')

            $objParsed = $strJson | ConvertFrom-Json

            # Assert
            $objParsed.Name | Should -Be 'MyRole'
            $objParsed.IsCustom | Should -BeTrue
            $objParsed.Description | Should -Be 'Desc'
            $objParsed.Actions | Should -Contain 'a/b/c'
            $objParsed.AssignableScopes | Should -Contain '/'
        }

        It "Includes empty NotActions and DataActions arrays" {
            # Arrange / Act
            $strJson = New-AzureRoleDefinitionJson `
                -RoleName 'R' `
                -Description 'D' `
                -Actions @('x') `
                -AssignableScopes @('/')

            $objParsed = $strJson | ConvertFrom-Json

            # Assert
            $objParsed.NotActions.Count | Should -Be 0
            $objParsed.DataActions.Count | Should -Be 0
            $objParsed.NotDataActions.Count | Should -Be 0
        }

        It "Correctly serializes multiple actions and scopes" {
            # Arrange
            $arrActions = @(
                'Microsoft.Compute/*/read',
                'Microsoft.Network/*/read',
                'Microsoft.Storage/*/read'
            )
            $arrScopes = @(
                '/subscriptions/sub-1',
                '/subscriptions/sub-2'
            )

            # Act
            $strJson = New-AzureRoleDefinitionJson `
                -RoleName 'MultiTest' `
                -Description 'Multi' `
                -Actions $arrActions `
                -AssignableScopes $arrScopes

            $objParsed = $strJson | ConvertFrom-Json

            # Assert
            $objParsed.Actions.Count | Should -Be 3
            $objParsed.AssignableScopes.Count | Should -Be 2
            $objParsed.Actions | Should -Contain 'Microsoft.Storage/*/read'
            $objParsed.AssignableScopes | Should -Contain '/subscriptions/sub-2'
        }
    }

    Context "When ConvertTo-Json fails" {
        BeforeAll {
            Mock ConvertTo-Json { throw 'Serialization failed' }
        }

        It "Throws a terminating error" {
            # Arrange / Act / Assert
            {
                New-AzureRoleDefinitionJson `
                    -RoleName 'FailRole' `
                    -Description 'D' `
                    -Actions @('a/b') `
                    -AssignableScopes @('/')
            } | Should -Throw '*Serialization failed*'
        }
    }

    Context "When -Verbose is specified" {
        It "Emits a verbose record containing the role name" {
            # Arrange / Act
            $arrVerbose = New-AzureRoleDefinitionJson `
                -RoleName 'VerboseTest' `
                -Description 'D' `
                -Actions @('a/b') `
                -AssignableScopes @('/') `
                -Verbose 4>&1 |
                Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }

            # Assert
            $arrVerbose | Should -Not -BeNullOrEmpty
            $arrVerbose[0].Message | Should -Match 'VerboseTest'
        }
    }
}
