BeforeAll {
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Edit-ReadActionCount.ps1')
}

Describe "Edit-ReadActionCount" {
    BeforeAll {
        $script:arrCounts = @(
            [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'microsoft.compute/virtualmachines/read'; Count = 100.0 }
            [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'microsoft.compute/virtualmachines/write'; Count = 50.0 }
        )
    }

    Context "When mode is Keep" {
        It "Returns counts unchanged" {
            # Arrange - uses $script:arrCounts from BeforeAll

            # Act
            $arrResult = @(Edit-ReadActionCount -Counts $script:arrCounts -Mode 'Keep')

            # Assert
            $arrResult.Count | Should -Be 2
            ($arrResult | Where-Object { $_.Action -like '*/read' }).Count | Should -Be 100.0
        }
    }

    Context "When mode is Exclude" {
        It "Removes read actions entirely" {
            # Arrange - uses $script:arrCounts from BeforeAll

            # Act
            $arrResult = @(Edit-ReadActionCount -Counts $script:arrCounts -Mode 'Exclude')

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].Action | Should -Be 'microsoft.compute/virtualmachines/write'
        }
    }

    Context "When mode is DownWeight" {
        It "Reduces read action counts by the weight factor" {
            # Arrange - uses $script:arrCounts from BeforeAll

            # Act
            $arrResult = @(Edit-ReadActionCount -Counts $script:arrCounts -Mode 'DownWeight' -ReadWeight 0.25)

            # Assert
            $arrResult.Count | Should -Be 2
            $objRead = $arrResult | Where-Object { $_.Action -like '*/read' }
            $objRead.Count | Should -Be 25.0
        }

        It "Does not modify non-read action counts" {
            # Arrange - uses $script:arrCounts from BeforeAll

            # Act
            $arrResult = @(Edit-ReadActionCount -Counts $script:arrCounts -Mode 'DownWeight' -ReadWeight 0.25)

            # Assert
            $objWrite = $arrResult | Where-Object { $_.Action -like '*/write' }
            $objWrite.Count | Should -Be 50.0
        }
    }

    Context "When using default parameter values" {
        It "Applies DownWeight mode with 0.25 weight by default" {
            # Arrange
            $arrTestCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'microsoft.compute/virtualmachines/read'; Count = 100.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'microsoft.compute/virtualmachines/write'; Count = 50.0 }
            )

            # Act
            $arrResult = @(Edit-ReadActionCount -Counts $arrTestCounts)

            # Assert
            $objRead = $arrResult | Where-Object { $_.Action -like '*/read' }
            $objRead.Count | Should -Be 25.0
        }
    }

    Context "When verifying output object structure" {
        It "Returns objects with PrincipalKey, Action, and Count properties" {
            # Arrange
            $arrTestCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'microsoft.compute/virtualmachines/write'; Count = 10.0 }
            )

            # Act
            $arrResult = @(Edit-ReadActionCount -Counts $arrTestCounts -Mode 'DownWeight' -ReadWeight 0.25)

            # Assert
            $arrExpectedProperties = @('PrincipalKey', 'Action', 'Count')
            $arrActualProperties = @($arrResult[0].PSObject.Properties.Name)
            $arrActualProperties | Sort-Object | Should -Be ($arrExpectedProperties | Sort-Object)
        }
    }

    Context "When all actions are read actions in Exclude mode" {
        It "Emits zero objects" {
            # Arrange
            $arrAllReadCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'microsoft.compute/virtualmachines/read'; Count = 100.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'microsoft.storage/storageaccounts/read'; Count = 200.0 }
            )

            # Act
            $arrResult = @(Edit-ReadActionCount -Counts $arrAllReadCounts -Mode 'Exclude')

            # Assert
            $arrResult.Count | Should -Be 0
        }
    }

    Context "When input is an empty array" {
        It "Handles empty input gracefully and emits zero objects" {
            # Arrange
            $arrEmptyCounts = @()

            # Act
            $arrResult = @(Edit-ReadActionCount -Counts $arrEmptyCounts -Mode 'Keep')

            # Assert
            $arrResult.Count | Should -Be 0
        }
    }
}
