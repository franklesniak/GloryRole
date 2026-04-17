BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'

    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-NormalizedAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-EntraIdResourceAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertFrom-EntraIdAuditRecord.ps1')
}

Describe "ConvertFrom-EntraIdAuditRecord" {
    Context "When the record result is not success" {
        It "Returns null for a failure result" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = 'failure'
                ActivityDisplayName = 'Add member to group'
                Category = 'GroupManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-1'
                        UserPrincipalName = 'admin@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = (Get-Date)
                CorrelationId = 'corr-1'
                Id = 'id-1'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }

        It "Returns null when result is null" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = $null
                ActivityDisplayName = 'Add member to group'
                Category = 'GroupManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-1'
                        UserPrincipalName = 'admin@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = (Get-Date)
                CorrelationId = 'corr-2'
                Id = 'id-2'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }
    }

    Context "When the principal cannot be resolved" {
        It "Returns null when InitiatedBy is null" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Add member to group'
                Category = 'GroupManagement'
                InitiatedBy = $null
                ActivityDateTime = (Get-Date)
                CorrelationId = 'corr-3'
                Id = 'id-3'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }

        It "Returns null when User.Id and App fields are all empty" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Add member to group'
                Category = 'GroupManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = ''
                        UserPrincipalName = ''
                    }
                    App = [pscustomobject]@{
                        AppId = ''
                        DisplayName = ''
                    }
                }
                ActivityDateTime = (Get-Date)
                CorrelationId = 'corr-4'
                Id = 'id-4'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }
    }

    Context "When the record is a valid user-initiated event" {
        It "Returns a CanonicalEntraIdEvent with User principal" {
            # Arrange
            $objRecord = [pscustomobject]@{
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
                ActivityDateTime = (Get-Date).AddHours(-1)
                CorrelationId = 'corr-5'
                Id = 'id-5'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Not -BeNullOrEmpty
            $objResult.PrincipalKey | Should -Be 'user-obj-1'
            $objResult.PrincipalType | Should -Be 'User'
            $objResult.Action | Should -Be 'microsoft.directory/groups/members/update'
            $objResult.Result | Should -Be 'success'
            $objResult.PrincipalUPN | Should -Be 'admin@contoso.com'
        }
    }

    Context "When the record is a valid app-initiated event" {
        It "Returns a CanonicalEntraIdEvent with ServicePrincipal principal via AppId" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Add user'
                Category = 'UserManagement'
                InitiatedBy = [pscustomobject]@{
                    User = $null
                    App = [pscustomobject]@{
                        AppId = 'app-id-789'
                        DisplayName = 'My Automation App'
                    }
                }
                ActivityDateTime = (Get-Date).AddHours(-2)
                CorrelationId = 'corr-6'
                Id = 'id-6'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Not -BeNullOrEmpty
            $objResult.PrincipalKey | Should -Be 'app-id-789'
            $objResult.PrincipalType | Should -Be 'ServicePrincipal'
            $objResult.Action | Should -Be 'microsoft.directory/users/create'
            $objResult.AppId | Should -Be 'app-id-789'
        }

        It "Falls back to App.DisplayName when AppId is empty" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Delete user'
                Category = 'UserManagement'
                InitiatedBy = [pscustomobject]@{
                    User = $null
                    App = [pscustomobject]@{
                        AppId = ''
                        DisplayName = 'Legacy App'
                    }
                }
                ActivityDateTime = (Get-Date).AddHours(-3)
                CorrelationId = 'corr-7'
                Id = 'id-7'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Not -BeNullOrEmpty
            $objResult.PrincipalKey | Should -Be 'Legacy App'
            $objResult.PrincipalType | Should -Be 'ServicePrincipal'
            $objResult.Action | Should -Be 'microsoft.directory/users/delete'
        }
    }

    Context "When activity display name is empty" {
        It "Returns null when ActivityDisplayName is empty" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = ''
                Category = 'GroupManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-2'
                        UserPrincipalName = 'admin@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = (Get-Date)
                CorrelationId = 'corr-8'
                Id = 'id-8'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }
    }

    Context "When the event uses an unmapped activity" {
        It "Returns null for unmapped activities" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Some Custom Activity'
                Category = 'CustomCategory'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-3'
                        UserPrincipalName = 'admin@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = (Get-Date)
                CorrelationId = 'corr-9'
                Id = 'id-9'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }

        It "Returns null for self-service audit events" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Self-service password reset flow activity progress'
                Category = 'UserManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-5'
                        UserPrincipalName = 'user@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = (Get-Date)
                CorrelationId = 'corr-11'
                Id = 'id-11'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }
    }

    Context "TimeGenerated normalization" {
        It "Normalizes a [datetime] ActivityDateTime to UTC [datetime]" {
            # Arrange
            $dtLocal = (Get-Date '2026-04-14T12:00:00')
            $objRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Add member to group'
                Category = 'GroupManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-dt-1'
                        UserPrincipalName = 'admin@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = $dtLocal
                CorrelationId = 'corr-dt-1'
                Id = 'id-dt-1'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Not -BeNullOrEmpty
            $objResult.TimeGenerated | Should -BeOfType ([datetime])
            $objResult.TimeGenerated.Kind | Should -Be ([System.DateTimeKind]::Utc)
        }

        It "Parses ISO-8601 string ActivityDateTime into [datetime]" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Add member to group'
                Category = 'GroupManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-dt-2'
                        UserPrincipalName = 'admin@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = '2026-04-14T09:15:30Z'
                CorrelationId = 'corr-dt-2'
                Id = 'id-dt-2'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Not -BeNullOrEmpty
            $objResult.TimeGenerated | Should -BeOfType ([datetime])
            $objResult.TimeGenerated.Year | Should -Be 2026
            $objResult.TimeGenerated.Month | Should -Be 4
            $objResult.TimeGenerated.Day | Should -Be 14
        }

        It "Returns null when ActivityDateTime is null" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Add member to group'
                Category = 'GroupManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-dt-3'
                        UserPrincipalName = 'admin@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = $null
                CorrelationId = 'corr-dt-3'
                Id = 'id-dt-3'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }

        It "Returns null when ActivityDateTime is an unparseable string" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Add member to group'
                Category = 'GroupManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-dt-4'
                        UserPrincipalName = 'admin@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = 'not-a-real-date'
                CorrelationId = 'corr-dt-4'
                Id = 'id-dt-4'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }
    }

    Context "Output object properties" {
        It "Contains all expected properties" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Add member to group'
                Category = 'GroupManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-4'
                        UserPrincipalName = 'admin@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = (Get-Date)
                CorrelationId = 'corr-10'
                Id = 'id-10'
            }

            # Act
            $objResult = ConvertFrom-EntraIdAuditRecord -Record $objRecord

            # Assert
            $arrExpected = @(
                'Action'
                'ActivityDisplayName'
                'AppId'
                'Category'
                'CorrelationId'
                'PrincipalKey'
                'PrincipalType'
                'PrincipalUPN'
                'RecordId'
                'Result'
                'TimeGenerated'
            )
            $arrActual = @($objResult.PSObject.Properties.Name | Sort-Object)
            $arrActual | Should -Be $arrExpected
        }
    }
}
