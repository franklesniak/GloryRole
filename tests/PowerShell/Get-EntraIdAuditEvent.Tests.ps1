BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'

    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-NormalizedAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-EntraIdResourceAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertFrom-EntraIdAuditRecord.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-EntraIdAuditEvent.ps1')

    # Stub function that mimics the Microsoft.Graph.Reports cmdlet
    # signature so Pester can Mock it without importing the module in CI.
    function Get-MgAuditLogDirectoryAudit {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSReviewUnusedParameter', '',
            Justification = 'Parameters exist to mirror the stubbed cmdlet signature so Pester Mocks bind correctly.')]
        [CmdletBinding()]
        param(
            [string]$Filter,
            [switch]$All
        )
    }
}

Describe "Get-EntraIdAuditEvent" {
    Context "When given successful audit records" {
        It "Returns expected CanonicalEntraIdEvent objects" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            $objMockRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Add member to group'
                Category = 'GroupManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-1'
                        UserPrincipalName = 'admin@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = $dtStart.AddHours(1)
                CorrelationId = 'corr-1'
                Id = 'id-1'
            }

            Mock Get-MgAuditLogDirectoryAudit { return @($objMockRecord) }

            # Act
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].PrincipalKey | Should -Be 'user-obj-1'
            $arrResult[0].Action | Should -Be 'microsoft.directory/groups/members/update'
        }

        It "Excludes null results from ConvertFrom-EntraIdAuditRecord" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            $objMockGood = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Add user'
                Category = 'UserManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-2'
                        UserPrincipalName = 'admin@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = $dtStart.AddHours(1)
                CorrelationId = 'corr-2'
                Id = 'id-2'
            }

            # This record has no principal - will be converted to $null
            $objMockBad = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Add user'
                Category = 'UserManagement'
                InitiatedBy = $null
                ActivityDateTime = $dtStart.AddHours(2)
                CorrelationId = 'corr-3'
                Id = 'id-3'
            }

            Mock Get-MgAuditLogDirectoryAudit { return @($objMockGood, $objMockBad) }

            # Act
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].PrincipalKey | Should -Be 'user-obj-2'
        }
    }

    Context "When no records are returned" {
        It "Returns an empty array" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            Mock Get-MgAuditLogDirectoryAudit { return @() }

            # Act
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult.Count | Should -Be 0
        }
    }

    Context "When FilterCategory is specified" {
        It "Passes category filter to Graph API query" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            Mock Get-MgAuditLogDirectoryAudit {
                return @()
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -FilterCategory @('GroupManagement'))

            # Assert
            $arrResult.Count | Should -Be 0
            # The constructed OData filter MUST contain the GroupManagement
            # category clause so the Graph query is actually scoped to that
            # category; assertion fails if -FilterCategory is ignored.
            Should -Invoke Get-MgAuditLogDirectoryAudit -Times 1 -ParameterFilter {
                $Filter -match "category eq 'GroupManagement'"
            }
        }

        It "Escapes single quotes in category values for OData safety" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            Mock Get-MgAuditLogDirectoryAudit {
                return @()
            }

            # Act - a pathological category containing a single quote
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -FilterCategory @("O'Brien"))

            # Assert - literal quote is doubled per OData grammar
            $arrResult.Count | Should -Be 0
            Should -Invoke Get-MgAuditLogDirectoryAudit -Times 1 -ParameterFilter {
                $Filter -match "category eq 'O''Brien'"
            }
        }

        It "Joins multiple category filters with 'or'" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            Mock Get-MgAuditLogDirectoryAudit {
                return @()
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -FilterCategory @('GroupManagement', 'UserManagement'))

            # Assert
            $arrResult.Count | Should -Be 0
            Should -Invoke Get-MgAuditLogDirectoryAudit -Times 1 -ParameterFilter {
                $Filter -match "category eq 'GroupManagement'" -and
                $Filter -match "category eq 'UserManagement'" -and
                $Filter -match " or "
            }
        }
    }

    Context "When Graph API throws an error" {
        It "Propagates the error" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            Mock Get-MgAuditLogDirectoryAudit { throw "Graph API connection failed" }

            # Act / Assert
            { Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd } | Should -Throw
        }
    }
}
