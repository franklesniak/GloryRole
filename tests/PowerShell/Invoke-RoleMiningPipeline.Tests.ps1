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
            $script:objResult = & $script:strScriptPath -InputMode CSV -CsvPath $script:strCsvPath -OutputPath $script:strOutputPath
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
            foreach ($objCluster in $script:objResult.ClusterActions) {
                $objCluster.PSObject.Properties.Name | Should -Contain 'Principals'
                ($objCluster.Principals -is [string[]]) -or ($objCluster.Principals -is [object[]]) | Should -BeTrue
                $objCluster.Principals.Count | Should -BeGreaterThan 0
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
                { & $script:strScriptPath -InputMode CSV -OutputPath $strOutputPath } | Should -Throw
            } finally {
                if (Test-Path -Path $strOutputPath) {
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

    Context "When verifying deterministic seeding" {
        BeforeAll {
            $script:strSeedOutputPath1 = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            $script:strSeedOutputPath2 = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            $script:objSeedResult1 = & $script:strScriptPath -InputMode CSV -CsvPath $script:strCsvPath -OutputPath $script:strSeedOutputPath1 -Seed 42
            $script:objSeedResult2 = & $script:strScriptPath -InputMode CSV -CsvPath $script:strCsvPath -OutputPath $script:strSeedOutputPath2 -Seed 42
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
            $script:objRangeResult = & $script:strScriptPath -InputMode CSV -CsvPath $script:strCsvPath -OutputPath $script:strRangeOutputPath

            # Count distinct principals in sample data for upper bound
            $arrCsvData = Import-Csv -Path $script:strCsvPath
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
}
