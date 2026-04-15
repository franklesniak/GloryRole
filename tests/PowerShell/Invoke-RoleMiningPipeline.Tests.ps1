BeforeAll {
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcRoot = Join-Path -Path $strRepoRoot -ChildPath 'src'
    $strSamplesRoot = Join-Path -Path $strRepoRoot -ChildPath 'samples'

    $script:strScriptPath = Join-Path -Path $strSrcRoot -ChildPath 'Invoke-RoleMiningPipeline.ps1'
    $script:strCsvPath = Join-Path -Path $strSamplesRoot -ChildPath 'principal_action_counts.csv'
}

Describe "Invoke-RoleMiningPipeline" {
    Context "When running in CSV mode with sample data" {
        BeforeAll {
            $script:strOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            $script:objResult = & $script:strScriptPath -InputMode CSV -CsvPath $script:strCsvPath -RoleSchema AzureRbac -OutputPath $script:strOutputPath
        }

        AfterAll {
            if (Test-Path -Path $script:strOutputPath) {
                Remove-Item -LiteralPath $script:strOutputPath -Recurse -Force
            }
        }

        It "Returns a non-null result" {
            # Assert
            $script:objResult | Should -Not -BeNullOrEmpty
        }

        It "Returns an object with the expected five properties" {
            # Arrange
            $arrExpected = @('Candidates', 'ClusterActions', 'OutputPath', 'Quality', 'RecommendedK')

            # Act
            $arrActual = @($script:objResult.PSObject.Properties.Name | Sort-Object)

            # Assert
            $arrActual | Should -Be $arrExpected
        }

        It "RecommendedK is an integer" {
            # Assert
            $script:objResult.RecommendedK | Should -BeOfType [int]
        }

        It "OutputPath equals the temporary output directory" {
            # Assert
            $script:objResult.OutputPath | Should -Be $script:strOutputPath
        }

        It "Exports principal_action_counts.csv to the output directory" {
            # Arrange
            $strFilePath = Join-Path -Path $script:strOutputPath -ChildPath 'principal_action_counts.csv'

            # Assert
            (Test-Path -Path $strFilePath) | Should -BeTrue
        }

        It "Exports features.txt to the output directory" {
            # Arrange
            $strFilePath = Join-Path -Path $script:strOutputPath -ChildPath 'features.txt'

            # Assert
            (Test-Path -Path $strFilePath) | Should -BeTrue
        }

        It "Exports quality.json to the output directory" {
            # Arrange
            $strFilePath = Join-Path -Path $script:strOutputPath -ChildPath 'quality.json'

            # Assert
            (Test-Path -Path $strFilePath) | Should -BeTrue
        }

        It "Exports autoK_candidates.csv to the output directory" {
            # Arrange
            $strFilePath = Join-Path -Path $script:strOutputPath -ChildPath 'autoK_candidates.csv'

            # Assert
            (Test-Path -Path $strFilePath) | Should -BeTrue
        }

        It "Exports clusters.json to the output directory" {
            # Arrange
            $strFilePath = Join-Path -Path $script:strOutputPath -ChildPath 'clusters.json'

            # Assert
            (Test-Path -Path $strFilePath) | Should -BeTrue
        }

        It "Each ClusterActions entry includes a Principals array" {
            # Assert
            $script:objResult.ClusterActions | Should -Not -BeNullOrEmpty
            foreach ($objCluster in $script:objResult.ClusterActions) {
                $objCluster.PSObject.Properties.Name | Should -Contain 'Principals'
                $objCluster.Principals | Should -Not -BeNullOrEmpty
                ($objCluster.Principals -is [string[]]) | Should -BeTrue
            }
        }

        It "Exports at least one role_cluster_*.json file to the output directory" {
            # Act
            $arrRoleFiles = @(Get-ChildItem -Path $script:strOutputPath -Filter 'role_cluster_*.json')

            # Assert
            $arrRoleFiles.Count | Should -BeGreaterThan 0
        }
    }

    Context "When given invalid input" {
        It "Throws when CsvPath is missing for CSV mode" {
            # Arrange
            $strOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            try {
                # Act / Assert
                { & $script:strScriptPath -InputMode CSV -RoleSchema AzureRbac -OutputPath $strOutputPath } | Should -Throw
            } finally {
                if (Test-Path -LiteralPath $strOutputPath) {
                    Remove-Item -LiteralPath $strOutputPath -Recurse -Force
                }
            }
        }

        It "Throws when SubscriptionIds is missing for ActivityLog mode" {
            # Arrange
            $strOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            try {
                # Act / Assert
                { & $script:strScriptPath -InputMode ActivityLog -OutputPath $strOutputPath -Start (Get-Date) -End (Get-Date) } | Should -Throw
            } finally {
                if (Test-Path -Path $strOutputPath) {
                    Remove-Item -LiteralPath $strOutputPath -Recurse -Force
                }
            }
        }

        It "Throws when Start and End are missing for ActivityLog mode" {
            # Arrange
            $strOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            try {
                # Act / Assert
                { & $script:strScriptPath -InputMode ActivityLog -OutputPath $strOutputPath -SubscriptionIds @('00000000-0000-0000-0000-000000000000') } | Should -Throw
            } finally {
                if (Test-Path -Path $strOutputPath) {
                    Remove-Item -LiteralPath $strOutputPath -Recurse -Force
                }
            }
        }

        It "Throws when WorkspaceId is missing for LogAnalytics mode" {
            # Arrange
            $strOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            try {
                # Act / Assert
                { & $script:strScriptPath -InputMode LogAnalytics -OutputPath $strOutputPath -Start (Get-Date) -End (Get-Date) } | Should -Throw
            } finally {
                if (Test-Path -Path $strOutputPath) {
                    Remove-Item -LiteralPath $strOutputPath -Recurse -Force
                }
            }
        }
    }

    Context "When all actions are pruned by the default thresholds" {
        BeforeAll {
            # Build a CSV whose data clears the stage-2 quality gate (>= 2
            # principals) but fails stage 3: every action is unique to a
            # single principal and has a total count below MinTotalCount=10,
            # so the pruner drops everything.
            $script:strPruneAllCsvPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath (([System.Guid]::NewGuid().ToString()) + '.csv')
            $arrRows = @(
                'PrincipalKey,Action,Count'
                'user-a,microsoft.compute/virtualmachines/read,1'
                'user-a,microsoft.compute/virtualmachines/write,2'
                'user-b,microsoft.storage/storageaccounts/read,1'
                'user-b,microsoft.storage/storageaccounts/write,2'
            )
            Set-Content -LiteralPath $script:strPruneAllCsvPath -Value $arrRows -Encoding UTF8
            $script:strPruneAllOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        }

        AfterAll {
            if (Test-Path -LiteralPath $script:strPruneAllCsvPath) {
                Remove-Item -LiteralPath $script:strPruneAllCsvPath -Force
            }
            if (Test-Path -LiteralPath $script:strPruneAllOutputPath) {
                Remove-Item -LiteralPath $script:strPruneAllOutputPath -Recurse -Force
            }
        }

        It "Throws a diagnostic error that includes the thresholds and best-observed stats" {
            # Act
            $objException = $null
            try {
                & $script:strScriptPath -InputMode CSV -CsvPath $script:strPruneAllCsvPath -RoleSchema AzureRbac -OutputPath $script:strPruneAllOutputPath
            } catch {
                $objException = $_
            }

            # Assert
            $objException | Should -Not -BeNullOrEmpty
            $objException.Exception.Message | Should -Match 'All actions were pruned'
            $objException.Exception.Message | Should -Match 'MinDistinctPrincipals=2'
            $objException.Exception.Message | Should -Match 'MinTotalCount=10'
            # The message should report how many principals and distinct
            # actions were in the data so the user can gauge how far off
            # their thresholds are.
            $objException.Exception.Message | Should -Match 'principal'
            $objException.Exception.Message | Should -Match 'action'
            # Every action in the fixture is unique to a single principal,
            # so the message should include the "no shared activity" hint
            # that guides users toward widening data collection rather
            # than just lowering thresholds.
            $objException.Exception.Message | Should -Match 'No action was performed by more than one principal'
        }
    }

    Context "When verifying deterministic seeding" {
        BeforeAll {
            $script:strSeedOutputPath1 = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            $script:strSeedOutputPath2 = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            $script:objSeedResult1 = & $script:strScriptPath -InputMode CSV -CsvPath $script:strCsvPath -RoleSchema AzureRbac -OutputPath $script:strSeedOutputPath1 -Seed 42
            $script:objSeedResult2 = & $script:strScriptPath -InputMode CSV -CsvPath $script:strCsvPath -RoleSchema AzureRbac -OutputPath $script:strSeedOutputPath2 -Seed 42
        }

        AfterAll {
            if (Test-Path -Path $script:strSeedOutputPath1) {
                Remove-Item -LiteralPath $script:strSeedOutputPath1 -Recurse -Force
            }
            if (Test-Path -Path $script:strSeedOutputPath2) {
                Remove-Item -LiteralPath $script:strSeedOutputPath2 -Recurse -Force
            }
        }

        It "Produces the same RecommendedK with the same seed" {
            # Assert
            $script:objSeedResult1.RecommendedK | Should -Be $script:objSeedResult2.RecommendedK
        }
    }

    Context "When verifying RecommendedK range" {
        BeforeAll {
            $script:strRangeOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            $script:objRangeResult = & $script:strScriptPath -InputMode CSV -CsvPath $script:strCsvPath -RoleSchema AzureRbac -OutputPath $script:strRangeOutputPath

            # Count distinct principals in sample data for upper bound
            $arrCsvData = Import-Csv -LiteralPath $script:strCsvPath
            $script:intPrincipalCount = ($arrCsvData | Select-Object -Property PrincipalKey -Unique).Count
        }

        AfterAll {
            if (Test-Path -Path $script:strRangeOutputPath) {
                Remove-Item -LiteralPath $script:strRangeOutputPath -Recurse -Force
            }
        }

        It "RecommendedK is greater than or equal to MinK default of 2" {
            # Assert
            $script:objRangeResult.RecommendedK | Should -BeGreaterOrEqual 2
        }

        It "RecommendedK is less than or equal to the number of principals" {
            # Assert
            $script:objRangeResult.RecommendedK | Should -BeLessOrEqual $script:intPrincipalCount
        }
    }

    Context "When resolving -RoleSchema for schema-neutral sources" {
        It "Throws when -RoleSchema is omitted with InputMode CSV" {
            # Arrange
            $strOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            try {
                # Act
                $objException = $null
                try {
                    & $script:strScriptPath -InputMode CSV -CsvPath $script:strCsvPath -OutputPath $strOutputPath
                } catch {
                    $objException = $_
                }

                # Assert
                $objException | Should -Not -BeNullOrEmpty
                $objException.Exception.Message | Should -Match "RoleSchema is required when InputMode is 'CSV'"
            } finally {
                if (Test-Path -LiteralPath $strOutputPath) {
                    Remove-Item -LiteralPath $strOutputPath -Recurse -Force
                }
            }
        }

        It "Throws when -RoleSchema is omitted with InputMode LogAnalytics" {
            # Arrange
            $strOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            try {
                # Act
                $objException = $null
                try {
                    & $script:strScriptPath -InputMode LogAnalytics -WorkspaceId 'w' -Start (Get-Date) -End (Get-Date) -OutputPath $strOutputPath
                } catch {
                    $objException = $_
                }

                # Assert
                $objException | Should -Not -BeNullOrEmpty
                $objException.Exception.Message | Should -Match "RoleSchema is required when InputMode is 'LogAnalytics'"
            } finally {
                if (Test-Path -LiteralPath $strOutputPath) {
                    Remove-Item -LiteralPath $strOutputPath -Recurse -Force
                }
            }
        }
    }

    Context "When validating -RoleSchema / -InputMode compatibility" {
        It "Throws when -RoleSchema 'EntraId' is passed with InputMode ActivityLog" {
            # Arrange
            $strOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            try {
                # Act
                $objException = $null
                try {
                    & $script:strScriptPath -InputMode ActivityLog -RoleSchema EntraId -SubscriptionIds @('00000000-0000-0000-0000-000000000000') -Start (Get-Date) -End (Get-Date) -OutputPath $strOutputPath
                } catch {
                    $objException = $_
                }

                # Assert
                $objException | Should -Not -BeNullOrEmpty
                $objException.Exception.Message | Should -Match "incompatible with InputMode 'ActivityLog'"
            } finally {
                if (Test-Path -LiteralPath $strOutputPath) {
                    Remove-Item -LiteralPath $strOutputPath -Recurse -Force
                }
            }
        }

        It "Throws when -RoleSchema 'AzureRbac' is passed with InputMode EntraId" {
            # Arrange
            $strOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            try {
                # Act
                $objException = $null
                try {
                    & $script:strScriptPath -InputMode EntraId -RoleSchema AzureRbac -Start (Get-Date) -End (Get-Date) -OutputPath $strOutputPath
                } catch {
                    $objException = $_
                }

                # Assert
                $objException | Should -Not -BeNullOrEmpty
                $objException.Exception.Message | Should -Match "incompatible with InputMode 'EntraId'"
            } finally {
                if (Test-Path -LiteralPath $strOutputPath) {
                    Remove-Item -LiteralPath $strOutputPath -Recurse -Force
                }
            }
        }
    }

    Context "When -RoleSchema is omitted for schema-constrained sources" {
        # Locks in the defaulting contract: InputMode 'ActivityLog' defaults
        # to RoleSchema 'AzureRbac' and InputMode 'EntraId' defaults to
        # RoleSchema 'EntraId'. These invocations will still fail downstream
        # (no Az / Microsoft.Graph context, fake subscription IDs, etc.),
        # but the error must NOT be the RoleSchema-required error (defaulting
        # must bypass that gate) nor a compatibility error. A regression that
        # removes the defaults would surface as a failure here.

        It "Does not throw a RoleSchema-related error when -RoleSchema is omitted with InputMode ActivityLog" {
            # Arrange
            $strOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            try {
                # Act
                $objException = $null
                try {
                    & $script:strScriptPath -InputMode ActivityLog -SubscriptionIds @('00000000-0000-0000-0000-000000000000') -Start (Get-Date) -End (Get-Date) -OutputPath $strOutputPath
                } catch {
                    $objException = $_
                }

                # Assert - any error raised must not be the RoleSchema gate
                if ($null -ne $objException) {
                    $objException.Exception.Message | Should -Not -Match "RoleSchema is required when InputMode is 'ActivityLog'"
                    $objException.Exception.Message | Should -Not -Match "incompatible with InputMode 'ActivityLog'"
                }
            } finally {
                if (Test-Path -LiteralPath $strOutputPath) {
                    Remove-Item -LiteralPath $strOutputPath -Recurse -Force
                }
            }
        }

        It "Does not throw a RoleSchema-related error when -RoleSchema is omitted with InputMode EntraId" {
            # Arrange
            $strOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            try {
                # Act
                $objException = $null
                try {
                    & $script:strScriptPath -InputMode EntraId -Start (Get-Date) -End (Get-Date) -OutputPath $strOutputPath
                } catch {
                    $objException = $_
                }

                # Assert - any error raised must not be the RoleSchema gate
                if ($null -ne $objException) {
                    $objException.Exception.Message | Should -Not -Match "RoleSchema is required when InputMode is 'EntraId'"
                    $objException.Exception.Message | Should -Not -Match "incompatible with InputMode 'EntraId'"
                }
            } finally {
                if (Test-Path -LiteralPath $strOutputPath) {
                    Remove-Item -LiteralPath $strOutputPath -Recurse -Force
                }
            }
        }
    }

    Context "When running in CSV mode with -RoleSchema EntraId against the Entra sample" {
        BeforeAll {
            $script:strEntraCsvPath = Join-Path -Path $strSamplesRoot -ChildPath 'entra_id_principal_action_counts.csv'
            $script:strEntraOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            $script:objEntraResult = & $script:strScriptPath -InputMode CSV -CsvPath $script:strEntraCsvPath -RoleSchema EntraId -OutputPath $script:strEntraOutputPath
        }

        AfterAll {
            if (Test-Path -LiteralPath $script:strEntraOutputPath) {
                Remove-Item -LiteralPath $script:strEntraOutputPath -Recurse -Force
            }
        }

        It "Returns a non-null result" {
            $script:objEntraResult | Should -Not -BeNullOrEmpty
        }

        It "Exports at least one entra_role_cluster_*.json file" {
            $arrEntraRoleFiles = @(Get-ChildItem -LiteralPath $script:strEntraOutputPath -Filter 'entra_role_cluster_*.json')
            $arrEntraRoleFiles.Count | Should -BeGreaterThan 0
        }

        It "Does not export any Azure RBAC role_cluster_*.json files" {
            $arrAzureRoleFiles = @(Get-ChildItem -LiteralPath $script:strEntraOutputPath -Filter 'role_cluster_*.json')
            $arrAzureRoleFiles.Count | Should -Be 0
        }

        It "Preserves camelCase segments in microsoft.directory/* actions through CSV ingestion" {
            # The default sample CSV uses all-lowercase action strings
            # that happen to already be valid Entra ID actions. To prove
            # the CSV->EntraId ingestion path does not downcase
            # camelCase segments (e.g., servicePrincipals,
            # oAuth2PermissionGrants), write an inline CSV with
            # deliberately camelCase actions and assert the emitted
            # unifiedRoleDefinition JSON preserves them verbatim.
            #
            # The dataset is sized comparable to the default sample
            # (10+ principals, 3+ distinct actions, varied counts to
            # produce natural cluster structure) so that K-Means
            # clustering and the Auto-K silhouette/Davies-Bouldin/
            # Calinski-Harabasz metrics all have enough data to
            # converge robustly on every supported platform.
            $strCamelCsvPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath (([System.Guid]::NewGuid().ToString()) + '.csv')
            $strCamelOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            try {
                $arrCsvLines = @(
                    '"PrincipalKey","Action","Count"'
                    # Cluster A: oAuth2PermissionGrants-heavy principals (service-principal admins)
                    '"admin-obj-001","microsoft.directory/oAuth2PermissionGrants/allProperties/update",45'
                    '"admin-obj-001","microsoft.directory/servicePrincipals/standard/read",12'
                    '"admin-obj-002","microsoft.directory/oAuth2PermissionGrants/allProperties/update",38'
                    '"admin-obj-002","microsoft.directory/servicePrincipals/standard/read",10'
                    '"admin-obj-003","microsoft.directory/oAuth2PermissionGrants/allProperties/update",40'
                    '"admin-obj-003","microsoft.directory/servicePrincipals/standard/read",15'
                    '"admin-obj-004","microsoft.directory/oAuth2PermissionGrants/allProperties/update",33'
                    # Cluster B: servicePrincipals-heavy principals (directory read-only)
                    '"admin-obj-005","microsoft.directory/servicePrincipals/standard/read",55'
                    '"admin-obj-005","microsoft.directory/oAuth2PermissionGrants/allProperties/update",8'
                    '"admin-obj-006","microsoft.directory/servicePrincipals/standard/read",60'
                    '"admin-obj-006","microsoft.directory/oAuth2PermissionGrants/allProperties/update",5'
                    '"admin-obj-007","microsoft.directory/servicePrincipals/standard/read",48'
                    # Cluster C: inviteGuest-heavy principals (guest admins)
                    '"admin-obj-008","microsoft.directory/inviteGuest",50'
                    '"admin-obj-008","microsoft.directory/users/basic/update",12'
                    '"admin-obj-009","microsoft.directory/inviteGuest",44'
                    '"admin-obj-009","microsoft.directory/users/basic/update",10'
                    '"admin-obj-010","microsoft.directory/inviteGuest",55'
                )
                $strCsvBody = $arrCsvLines -join [System.Environment]::NewLine
                Set-Content -LiteralPath $strCamelCsvPath -Value $strCsvBody -Encoding UTF8

                $null = & $script:strScriptPath -InputMode CSV -CsvPath $strCamelCsvPath -RoleSchema EntraId -OutputPath $strCamelOutputPath

                $arrEntraRoleFiles = @(Get-ChildItem -LiteralPath $strCamelOutputPath -Filter 'entra_role_cluster_*.json')
                $arrEntraRoleFiles.Count | Should -BeGreaterThan 0

                $listAllActions = [System.Collections.Generic.List[string]]::new()
                foreach ($objFile in $arrEntraRoleFiles) {
                    $strJson = Get-Content -LiteralPath $objFile.FullName -Raw
                    $objJson = $strJson | ConvertFrom-Json
                    foreach ($objPerm in @($objJson.rolePermissions)) {
                        foreach ($strAct in @($objPerm.allowedResourceActions)) {
                            [void]$listAllActions.Add([string]$strAct)
                        }
                    }
                }

                # Positive: camelCase segments are preserved verbatim.
                $listAllActions | Should -Contain 'microsoft.directory/oAuth2PermissionGrants/allProperties/update'
                $listAllActions | Should -Contain 'microsoft.directory/servicePrincipals/standard/read'
                $listAllActions | Should -Contain 'microsoft.directory/inviteGuest'
                # Negative: downcased forms must be absent anywhere in the emitted JSON.
                # Use -ccontains (case-sensitive) because Pester's Should -Contain
                # is case-insensitive and would match the camelCase originals.
                ($listAllActions -ccontains 'microsoft.directory/oauth2permissiongrants/allproperties/update') | Should -BeFalse
                ($listAllActions -ccontains 'microsoft.directory/serviceprincipals/standard/read') | Should -BeFalse
                ($listAllActions -ccontains 'microsoft.directory/inviteguest') | Should -BeFalse
            } finally {
                if (Test-Path -LiteralPath $strCamelCsvPath) {
                    Remove-Item -LiteralPath $strCamelCsvPath -Force
                }
                if (Test-Path -LiteralPath $strCamelOutputPath) {
                    Remove-Item -LiteralPath $strCamelOutputPath -Recurse -Force
                }
            }
        }
    }
}
