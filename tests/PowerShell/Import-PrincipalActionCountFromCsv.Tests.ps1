BeforeAll {
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-NormalizedAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Import-PrincipalActionCountFromCsv.ps1')
}

Describe "Import-PrincipalActionCountFromCsv" {
    Context "When given a valid CSV file" {
        It "Imports sparse triples correctly" {
            # Arrange
            $strPath = Join-Path -Path $strRepoRoot -ChildPath (Join-Path -Path 'samples' -ChildPath 'principal_action_counts.csv')

            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $strPath)

            # Assert
            $arrResult.Count | Should -BeGreaterThan 0
            $arrResult[0].PrincipalKey | Should -Not -BeNullOrEmpty
            $arrResult[0].Action | Should -Not -BeNullOrEmpty
            $arrResult[0].Count | Should -BeGreaterThan 0
        }

        It "Normalizes actions to lowercase" {
            # Arrange
            $strPath = Join-Path -Path $strRepoRoot -ChildPath (Join-Path -Path 'samples' -ChildPath 'principal_action_counts.csv')

            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $strPath)

            # Assert
            foreach ($objRow in $arrResult) {
                $objRow.Action | Should -BeExactly $objRow.Action.ToLowerInvariant()
            }
        }
    }

    Context "When verifying output contract" {
        It "Returns objects with exactly PrincipalKey, Action, and Count properties" {
            # Arrange
            $strPath = Join-Path -Path $strRepoRoot -ChildPath (Join-Path -Path 'samples' -ChildPath 'principal_action_counts.csv')

            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $strPath)

            # Assert
            foreach ($objRow in $arrResult) {
                $arrPropertyNames = @($objRow.PSObject.Properties.Name | Sort-Object)
                $arrPropertyNames | Should -Be @('Action', 'Count', 'PrincipalKey')
            }
        }
    }

    Context "When CSV contains blank actions" {
        BeforeAll {
            $strTempFileName = [System.IO.Path]::GetRandomFileName()
            $script:strTempCsvPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $strTempFileName
            $strCsvContent = @(
                'PrincipalKey,Action,Count'
                'user1,microsoft.authorization/roleassignments/write,5'
                'user2,,3'
                'user3,   ,2'
                'user4,microsoft.compute/virtualmachines/start/action,1'
            ) -join [System.Environment]::NewLine
            Set-Content -LiteralPath $script:strTempCsvPath -Value $strCsvContent -Encoding UTF8
        }

        AfterAll {
            if (Test-Path -LiteralPath $script:strTempCsvPath) {
                Remove-Item -LiteralPath $script:strTempCsvPath -Force
            }
        }

        It "Skips rows with empty or whitespace-only actions" {
            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $script:strTempCsvPath)

            # Assert
            $arrResult.Count | Should -Be 2
            $arrResult[0].PrincipalKey | Should -Be 'user1'
            $arrResult[1].PrincipalKey | Should -Be 'user4'
        }
    }

    Context "When given a nonexistent file" {
        It "Throws an error" {
            # Act / Assert
            { Import-PrincipalActionCountFromCsv -Path 'nonexistent.csv' } | Should -Throw
        }
    }

    Context "When -RoleSchema is 'EntraId'" {
        BeforeAll {
            $strTempFileName = [System.IO.Path]::GetRandomFileName()
            $script:strEntraCsvPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $strTempFileName
            $strCsvContent = @(
                'PrincipalKey,Action,Count'
                'admin-001,microsoft.directory/oAuth2PermissionGrants/allProperties/update,10'
                'admin-001,microsoft.directory/servicePrincipals/standard/read,15'
                'admin-002,microsoft.directory/inviteGuest,5'
                'admin-003,"  microsoft.directory/users/basic/update  ",8'
                'admin-004,,3'
                'admin-005,"   ",2'
            ) -join [System.Environment]::NewLine
            Set-Content -LiteralPath $script:strEntraCsvPath -Value $strCsvContent -Encoding UTF8
        }

        AfterAll {
            if (Test-Path -LiteralPath $script:strEntraCsvPath) {
                Remove-Item -LiteralPath $script:strEntraCsvPath -Force
            }
        }

        It "Preserves camelCase segments in microsoft.directory/* actions (does not lowercase)" {
            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $script:strEntraCsvPath -RoleSchema EntraId)

            # Assert - only the 4 non-blank rows survive
            $arrResult.Count | Should -Be 4
            $arrActions = @($arrResult | Select-Object -ExpandProperty Action)
            $arrActions | Should -Contain 'microsoft.directory/oAuth2PermissionGrants/allProperties/update'
            $arrActions | Should -Contain 'microsoft.directory/servicePrincipals/standard/read'
            $arrActions | Should -Contain 'microsoft.directory/inviteGuest'
            $arrActions | Should -Contain 'microsoft.directory/users/basic/update'
            # The camelCase forms MUST NOT have been downcased.
            # Use -ccontains (case-sensitive) because Pester's Should -Contain
            # is case-insensitive and would match the camelCase originals.
            ($arrActions -ccontains 'microsoft.directory/oauth2permissiongrants/allproperties/update') | Should -BeFalse
            ($arrActions -ccontains 'microsoft.directory/serviceprincipals/standard/read') | Should -BeFalse
            ($arrActions -ccontains 'microsoft.directory/inviteguest') | Should -BeFalse
        }

        It "Trims whitespace around actions but does not change case" {
            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $script:strEntraCsvPath -RoleSchema EntraId)

            # Assert - the quoted `"  microsoft.directory/users/basic/update  "` is trimmed
            $objTrimmedRow = $arrResult | Where-Object { $_.PrincipalKey -eq 'admin-003' }
            $objTrimmedRow | Should -Not -BeNullOrEmpty
            $objTrimmedRow.Action | Should -BeExactly 'microsoft.directory/users/basic/update'
        }

        It "Skips rows with empty or whitespace-only actions" {
            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $script:strEntraCsvPath -RoleSchema EntraId)

            # Assert - admin-004 (empty) and admin-005 (whitespace) are skipped
            $arrPrincipals = @($arrResult | Select-Object -ExpandProperty PrincipalKey)
            $arrPrincipals | Should -Not -Contain 'admin-004'
            $arrPrincipals | Should -Not -Contain 'admin-005'
        }
    }

    Context "When -RoleSchema default is used (AzureRbac)" {
        BeforeAll {
            $strTempFileName = [System.IO.Path]::GetRandomFileName()
            $script:strDefaultCsvPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $strTempFileName
            $strCsvContent = @(
                'PrincipalKey,Action,Count'
                'user-001,Microsoft.Compute/virtualMachines/Read,10'
                'user-001,microsoft.directory/oAuth2PermissionGrants/allProperties/update,5'
            ) -join [System.Environment]::NewLine
            Set-Content -LiteralPath $script:strDefaultCsvPath -Value $strCsvContent -Encoding UTF8
        }

        AfterAll {
            if (Test-Path -LiteralPath $script:strDefaultCsvPath) {
                Remove-Item -LiteralPath $script:strDefaultCsvPath -Force
            }
        }

        It "Lowercases actions when RoleSchema is omitted (default AzureRbac)" {
            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $script:strDefaultCsvPath)

            # Assert - default behavior lowercases everything
            $arrActions = @($arrResult | Select-Object -ExpandProperty Action)
            $arrActions | Should -Contain 'microsoft.compute/virtualmachines/read'
            $arrActions | Should -Contain 'microsoft.directory/oauth2permissiongrants/allproperties/update'
            # Use -ccontains (case-sensitive) because Pester's Should -Contain
            # is case-insensitive and would match the lowercased forms.
            ($arrActions -ccontains 'Microsoft.Compute/virtualMachines/Read') | Should -BeFalse
            ($arrActions -ccontains 'microsoft.directory/oAuth2PermissionGrants/allProperties/update') | Should -BeFalse
        }

        It "Lowercases actions when RoleSchema is 'AzureRbac' explicitly" {
            # Act
            $arrResult = @(Import-PrincipalActionCountFromCsv -Path $script:strDefaultCsvPath -RoleSchema AzureRbac)

            # Assert
            $arrActions = @($arrResult | Select-Object -ExpandProperty Action)
            $arrActions | Should -Contain 'microsoft.compute/virtualmachines/read'
            $arrActions | Should -Contain 'microsoft.directory/oauth2permissiongrants/allproperties/update'
        }
    }
}
