BeforeAll {
    # Stub function that mimics the real Az.OperationalInsights cmdlet so Pester
    # can Mock it without importing Az.OperationalInsights in CI. The
    # parameters exist to match the real cmdlet's interface (callers set them),
    # and the body intentionally does nothing.
    function Invoke-AzOperationalInsightsQuery {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSReviewUnusedParameter', '',
            Justification = 'Parameters exist to mirror the stubbed cmdlet signature so Pester Mocks bind correctly.')]
        [CmdletBinding()]
        param ($WorkspaceId, $Query)
    }
    # Avoid relative-path segments per style guide checklist item
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-NormalizedAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Import-PrincipalActionCountFromLogAnalytics.ps1')
}

Describe "Import-PrincipalActionCountFromLogAnalytics" {
    Context "When query returns valid results" {
        It "Streams pscustomobject results with correct properties" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            $objMockResults = @(
                [pscustomobject]@{ PrincipalKey = 'user-001'; Action = 'microsoft.compute/virtualmachines/read'; Count = '5' }
                [pscustomobject]@{ PrincipalKey = 'user-002'; Action = 'microsoft.storage/storageaccounts/write'; Count = '3' }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = $objMockResults }
            }

            # Act
            $arrResult = @(Import-PrincipalActionCountFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult | Should -HaveCount 2
            $arrResult[0].PrincipalKey | Should -Be 'user-001'
            $arrResult[0].Action | Should -Be 'microsoft.compute/virtualmachines/read'
            $arrResult[0].Count | Should -BeOfType [double]
            $arrResult[0].Count | Should -Be 5
            $arrResult[1].PrincipalKey | Should -Be 'user-002'
            $arrResult[1].Action | Should -Be 'microsoft.storage/storageaccounts/write'
            $arrResult[1].Count | Should -BeOfType [double]
            $arrResult[1].Count | Should -Be 3
        }
    }

    Context "When actions require normalization" {
        It "Normalizes actions to lowercase" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            $objMockResults = @(
                [pscustomobject]@{ PrincipalKey = 'user-001'; Action = 'Microsoft.Compute/VirtualMachines/Read'; Count = '2' }
                [pscustomobject]@{ PrincipalKey = 'user-002'; Action = 'MICROSOFT.STORAGE/STORAGEACCOUNTS/WRITE'; Count = '7' }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = $objMockResults }
            }

            # Act
            $arrResult = @(Import-PrincipalActionCountFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult | Should -HaveCount 2
            $arrResult[0].Action | Should -BeExactly 'microsoft.compute/virtualmachines/read'
            $arrResult[1].Action | Should -BeExactly 'microsoft.storage/storageaccounts/write'
        }
    }

    Context "When actions are blank after normalization" {
        It "Skips rows with blank or whitespace-only actions" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            $objMockResults = @(
                [pscustomobject]@{ PrincipalKey = 'user-001'; Action = 'microsoft.compute/virtualmachines/read'; Count = '1' }
                [pscustomobject]@{ PrincipalKey = 'user-002'; Action = '   '; Count = '4' }
                [pscustomobject]@{ PrincipalKey = 'user-003'; Action = ''; Count = '2' }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = $objMockResults }
            }
            Mock ConvertTo-NormalizedAction {
                param ($Action)
                if ([string]::IsNullOrWhiteSpace($Action)) {
                    return $null
                }
                return $Action.Trim().ToLowerInvariant()
            }

            # Act
            $arrResult = @(Import-PrincipalActionCountFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult | Should -HaveCount 1
            $arrResult[0].PrincipalKey | Should -Be 'user-001'
        }
    }

    Context "When query fails" {
        It "Throws a descriptive error message" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            Mock Invoke-AzOperationalInsightsQuery {
                throw "Connection timed out"
            }

            # Act / Assert
            { Import-PrincipalActionCountFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd } | Should -Throw '*Connection timed out*'
        }
    }

    Context "When query returns empty results" {
        It "Produces no output" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = @() }
            }

            # Act
            $arrResult = @(Import-PrincipalActionCountFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult | Should -HaveCount 0
        }
    }
}
