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

            # Act / Assert - disable retries so the error propagates
            # immediately without waiting through backoff delays.
            { Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -MaxRetries 0 } | Should -Throw
        }
    }

    Context "When UnmappedActivityAccumulator is provided" {
        It "Populates the accumulator for unmapped activities" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $hashUnmapped = @{}

            $objMockMapped = [pscustomobject]@{
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

            $objMockUnmapped = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Self-service password reset flow activity progress'
                Category = 'UserManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-2'
                        UserPrincipalName = 'user@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = $dtStart.AddHours(2)
                CorrelationId = 'corr-2'
                Id = 'id-2'
            }

            Mock Get-MgAuditLogDirectoryAudit { return @($objMockMapped, $objMockUnmapped) }

            # Act
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -UnmappedActivityAccumulator $hashUnmapped)

            # Assert - only mapped event is returned
            $arrResult.Count | Should -Be 1
            $arrResult[0].PrincipalKey | Should -Be 'user-obj-1'

            # Assert - accumulator has the unmapped activity
            $hashUnmapped.Count | Should -Be 1
            $strExpectedKey = 'Self-service password reset flow activity progress|UserManagement'
            $hashUnmapped.ContainsKey($strExpectedKey) | Should -BeTrue
            $hashUnmapped[$strExpectedKey].ActivityDisplayName | Should -Be 'Self-service password reset flow activity progress'
            $hashUnmapped[$strExpectedKey].Category | Should -Be 'UserManagement'
            $hashUnmapped[$strExpectedKey].Count | Should -Be 1
            $hashUnmapped[$strExpectedKey].SampleCorrelationId | Should -Be 'corr-2'
            $hashUnmapped[$strExpectedKey].SampleRecordId | Should -Be 'id-2'
        }

        It "Increments count for repeated unmapped activities" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $hashUnmapped = @{}

            $objMockUnmapped1 = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'User registered security info'
                Category = 'UserManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-1'
                        UserPrincipalName = 'user1@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = $dtStart.AddHours(1)
                CorrelationId = 'corr-1'
                Id = 'id-1'
            }

            $objMockUnmapped2 = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'User registered security info'
                Category = 'UserManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-2'
                        UserPrincipalName = 'user2@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = $dtStart.AddHours(2)
                CorrelationId = 'corr-2'
                Id = 'id-2'
            }

            Mock Get-MgAuditLogDirectoryAudit { return @($objMockUnmapped1, $objMockUnmapped2) }

            # Act
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -UnmappedActivityAccumulator $hashUnmapped)

            # Assert - no mapped events
            $arrResult.Count | Should -Be 0

            # Assert - accumulator has one entry with count 2
            $hashUnmapped.Count | Should -Be 1
            $strExpectedKey = 'User registered security info|UserManagement'
            $hashUnmapped[$strExpectedKey].Count | Should -Be 2
            # Sample IDs come from the first occurrence
            $hashUnmapped[$strExpectedKey].SampleCorrelationId | Should -Be 'corr-1'
        }

        It "Does not track non-success records as unmapped" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $hashUnmapped = @{}

            $objMockFailed = [pscustomobject]@{
                Result = 'failure'
                ActivityDisplayName = 'Some unknown activity'
                Category = 'Other'
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

            Mock Get-MgAuditLogDirectoryAudit { return @($objMockFailed) }

            # Act
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -UnmappedActivityAccumulator $hashUnmapped)

            # Assert
            $arrResult.Count | Should -Be 0
            $hashUnmapped.Count | Should -Be 0
        }

        It "Does not track records dropped for missing principal as unmapped" {
            # Arrange - success + unmapped activity, but InitiatedBy is
            # null, so the record is dropped for principal failure. The
            # accumulator MUST NOT count this as an unmapped activity
            # because the primary reason for dropping was data quality,
            # not mapping coverage.
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $hashUnmapped = @{}

            $objMockNoPrincipal = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Self-service password reset flow activity progress'
                Category = 'UserManagement'
                InitiatedBy = $null
                ActivityDateTime = $dtStart.AddHours(1)
                CorrelationId = 'corr-1'
                Id = 'id-1'
            }

            Mock Get-MgAuditLogDirectoryAudit { return @($objMockNoPrincipal) }

            # Act
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -UnmappedActivityAccumulator $hashUnmapped)

            # Assert
            $arrResult.Count | Should -Be 0
            $hashUnmapped.Count | Should -Be 0
        }

        It "Does not track records dropped for unparseable ActivityDateTime as unmapped" {
            # Arrange - success + principal + unmapped activity, but
            # ActivityDateTime is not parseable. The record is dropped
            # for date failure and MUST NOT be counted as unmapped.
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $hashUnmapped = @{}

            $objMockBadDate = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'Self-service password reset flow activity progress'
                Category = 'UserManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-1'
                        UserPrincipalName = 'user@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = 'not-a-real-date'
                CorrelationId = 'corr-1'
                Id = 'id-1'
            }

            Mock Get-MgAuditLogDirectoryAudit { return @($objMockBadDate) }

            # Act
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -UnmappedActivityAccumulator $hashUnmapped)

            # Assert
            $arrResult.Count | Should -Be 0
            $hashUnmapped.Count | Should -Be 0
        }

        It "Does not populate accumulator when parameter is not provided" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            $objMockUnmapped = [pscustomobject]@{
                Result = 'success'
                ActivityDisplayName = 'User registered security info'
                Category = 'UserManagement'
                InitiatedBy = [pscustomobject]@{
                    User = [pscustomobject]@{
                        Id = 'user-obj-1'
                        UserPrincipalName = 'user@contoso.com'
                    }
                    App = $null
                }
                ActivityDateTime = $dtStart.AddHours(1)
                CorrelationId = 'corr-1'
                Id = 'id-1'
            }

            Mock Get-MgAuditLogDirectoryAudit { return @($objMockUnmapped) }

            # Act - should not throw even though unmapped activities exist
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult.Count | Should -Be 0
        }
    }

    Context "When Graph API fails transiently then succeeds (retry/backoff)" {
        BeforeEach {
            Mock Start-Sleep { }
        }

        It "Retries and returns results on subsequent success" {
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

            $script:intCallCount = 0
            Mock Get-MgAuditLogDirectoryAudit {
                $script:intCallCount++
                if ($script:intCallCount -le 2) {
                    throw "Service Unavailable"
                }
                return @($objMockRecord)
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].PrincipalKey | Should -Be 'user-obj-1'
            Should -Invoke Get-MgAuditLogDirectoryAudit -Times 3 -Exactly
            Should -Invoke Start-Sleep -Times 2 -Exactly
        }

        It "Throws after exhausting MaxRetries" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            Mock Get-MgAuditLogDirectoryAudit {
                throw "Service Unavailable"
            }

            # Act / Assert - with MaxRetries=2, total attempts = 3
            { Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -MaxRetries 2 } | Should -Throw
            Should -Invoke Get-MgAuditLogDirectoryAudit -Times 3 -Exactly
            Should -Invoke Start-Sleep -Times 2 -Exactly
        }

        It "Does not retry when MaxRetries is 0" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            Mock Get-MgAuditLogDirectoryAudit {
                throw "Service Unavailable"
            }

            # Act / Assert - MaxRetries=0 means only the initial attempt
            { Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -MaxRetries 0 } | Should -Throw
            Should -Invoke Get-MgAuditLogDirectoryAudit -Times 1 -Exactly
            Should -Invoke Start-Sleep -Times 0 -Exactly
        }

        It "Succeeds on the last allowed retry attempt" {
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

            # Fail on first 2 attempts, succeed on 3rd (last allowed
            # when MaxRetries=2)
            $script:intCallCount = 0
            Mock Get-MgAuditLogDirectoryAudit {
                $script:intCallCount++
                if ($script:intCallCount -le 2) {
                    throw "Service Unavailable"
                }
                return @($objMockRecord)
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -MaxRetries 2)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].PrincipalKey | Should -Be 'user-obj-1'
            Should -Invoke Get-MgAuditLogDirectoryAudit -Times 3 -Exactly
            Should -Invoke Start-Sleep -Times 2 -Exactly
        }

        It "Calls Start-Sleep with increasing delay values (exponential backoff)" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            $script:arrSleepMs = @()
            Mock Start-Sleep {
                $script:arrSleepMs += $Milliseconds
            }

            Mock Get-MgAuditLogDirectoryAudit {
                throw "Service Unavailable"
            }

            # Suppress jitter for deterministic assertions by mocking
            # Get-Random to return 0. Jitter adds 0-1s, so delays
            # should be at least base * 2^N seconds.
            Mock Get-Random { return 0 }

            # Act - MaxRetries=3, RetryBaseDelaySeconds=2
            { Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -MaxRetries 3 -RetryBaseDelaySeconds 2 } | Should -Throw

            # Assert - 3 sleeps with increasing delays
            $script:arrSleepMs | Should -HaveCount 3
            # With zero jitter: 2^0 * 2 = 2s, 2^1 * 2 = 4s, 2^2 * 2 = 8s
            $script:arrSleepMs[0] | Should -Be 2000
            $script:arrSleepMs[1] | Should -Be 4000
            $script:arrSleepMs[2] | Should -Be 8000
        }

        It "Emits verbose retry diagnostics" {
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

            $script:intCallCount = 0
            Mock Get-MgAuditLogDirectoryAudit {
                $script:intCallCount++
                if ($script:intCallCount -eq 1) {
                    throw "Service Unavailable"
                }
                return @($objMockRecord)
            }

            # Act - capture verbose output
            $arrResult = @(Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -Verbose 4>&1)

            # Assert - verbose stream should contain retry messages.
            # Separate pipeline objects from verbose records.
            $arrVerboseMessages = @($arrResult | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })
            $arrVerboseMessages | Should -Not -BeNullOrEmpty
            $strAllVerbose = ($arrVerboseMessages | ForEach-Object { $_.Message }) -join "`n"
            $strAllVerbose | Should -Match 'Retrying in'
            $strAllVerbose | Should -Match 'succeeded on attempt 2'
        }

        It "Throws immediately on non-retriable HTTP 401 without retrying" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            Mock Get-MgAuditLogDirectoryAudit {
                $objException = [System.Exception]::new("Unauthorized")
                $objException | Add-Member -MemberType NoteProperty -Name 'Response' -Value ([pscustomobject]@{ StatusCode = 401 })
                throw $objException
            }

            # Act / Assert - 401 is non-retriable; the classifier
            # must surface the failure on the first attempt without
            # backoff or additional Graph call attempts.
            { Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -MaxRetries 3 } | Should -Throw
            Should -Invoke Get-MgAuditLogDirectoryAudit -Times 1 -Exactly
            Should -Invoke Start-Sleep -Times 0 -Exactly
        }

        It "Throws immediately on CommandNotFoundException without retrying" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date

            Mock Get-MgAuditLogDirectoryAudit {
                throw [System.Management.Automation.CommandNotFoundException]::new("The module is not loaded.")
            }

            # Act / Assert - CommandNotFoundException indicates a
            # permanent local configuration problem (e.g.,
            # Microsoft.Graph.Reports not loaded); the classifier
            # must fail fast without invoking Start-Sleep.
            { Get-EntraIdAuditEvent -Start $dtStart -End $dtEnd -MaxRetries 3 } | Should -Throw
            Should -Invoke Get-MgAuditLogDirectoryAudit -Times 1 -Exactly
            Should -Invoke Start-Sleep -Times 0 -Exactly
        }
    }
}
