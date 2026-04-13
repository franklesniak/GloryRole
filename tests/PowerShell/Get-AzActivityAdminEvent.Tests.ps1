BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'

    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertFrom-ClaimsJson.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Resolve-PrincipalKey.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Resolve-LocalizableStringValue.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-NormalizedAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertFrom-AzActivityLogRecord.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-AzActivityAdminEvent.ps1')

    # Stub functions that mimic the real Az module cmdlet signatures so Pester
    # can Mock them without importing Az.Accounts / Az.Monitor in CI. The
    # parameters exist to match the real cmdlets' interfaces (callers set them),
    # and the bodies intentionally do nothing.
    function Set-AzContext {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSUseShouldProcessForStateChangingFunctions', '',
            Justification = 'Test stub mimicking the Az.Accounts cmdlet signature; no real state change occurs.')]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSReviewUnusedParameter', '',
            Justification = 'Parameter exists to mirror the stubbed cmdlet signature so Pester Mocks bind correctly.')]
        [CmdletBinding()]
        param(
            [string]$SubscriptionId
        )
    }

    function Get-AzActivityLog {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSReviewUnusedParameter', '',
            Justification = 'Parameters exist to mirror the stubbed cmdlet signature so Pester Mocks bind correctly.')]
        [CmdletBinding()]
        param(
            [datetime]$StartTime,
            [datetime]$EndTime,
            [int]$MaxRecord,
            [switch]$DetailedOutput
        )
    }
}

Describe "Get-AzActivityAdminEvent" {
    Context "When given a single subscription with successful events" {
        It "Returns expected CanonicalAdminEvent objects for successful records" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $arrSubscriptionIds = @('sub-1')

            $objMockRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-1","http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn":"user@example.com"}'
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Compute/virtualMachines/write' }
                OperationName = [pscustomobject]@{ Value = 'Microsoft.Compute/virtualMachines/write' }
                Caller = 'user@example.com'
                EventTimestamp = $dtStart.AddHours(1)
                SubscriptionId = 'sub-1'
                Status = [pscustomobject]@{ Value = 'Succeeded' }
                ResourceId = '/subscriptions/sub-1/providers/Microsoft.Compute/virtualMachines/vm1'
                CorrelationId = 'corr-1'
            }

            Mock Set-AzContext { }
            Mock Get-AzActivityLog { return @($objMockRecord) }

            # Act
            $arrResult = @(Get-AzActivityAdminEvent -Start $dtStart -End $dtEnd -SubscriptionIds $arrSubscriptionIds -InitialSliceHours 25)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].Status | Should -Be 'Succeeded'
            $arrResult[0].PrincipalKey | Should -Be 'oid-1'
        }

        It "Excludes null results from ConvertFrom-AzActivityLogRecord" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $arrSubscriptionIds = @('sub-1')

            $objValidRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-1","http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn":"user@example.com"}'
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Compute/virtualMachines/write' }
                OperationName = [pscustomobject]@{ Value = 'Microsoft.Compute/virtualMachines/write' }
                Caller = 'user@example.com'
                EventTimestamp = $dtStart.AddHours(1)
                SubscriptionId = 'sub-1'
                Status = [pscustomobject]@{ Value = 'Succeeded' }
                ResourceId = '/subscriptions/sub-1/providers/Microsoft.Compute/virtualMachines/vm1'
                CorrelationId = 'corr-1'
            }

            $objNullRecord = [pscustomobject]@{
                Category = 'Policy'
                Claims = $null
                Authorization = $null
                OperationName = $null
                Caller = ''
                EventTimestamp = $dtStart.AddHours(2)
                SubscriptionId = 'sub-1'
                Status = [pscustomobject]@{ Value = 'Succeeded' }
                ResourceId = '/subscriptions/sub-1'
                CorrelationId = 'corr-2'
            }

            Mock Set-AzContext { }
            Mock Get-AzActivityLog { return @($objValidRecord, $objNullRecord) }

            # Act
            $arrResult = @(Get-AzActivityAdminEvent -Start $dtStart -End $dtEnd -SubscriptionIds $arrSubscriptionIds -InitialSliceHours 25)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].PrincipalKey | Should -Be 'oid-1'
        }

        It "Excludes non-Succeeded events from output" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $arrSubscriptionIds = @('sub-1')

            $objFailedRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-1","http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn":"user@example.com"}'
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Compute/virtualMachines/write' }
                OperationName = [pscustomobject]@{ Value = 'Microsoft.Compute/virtualMachines/write' }
                Caller = 'user@example.com'
                EventTimestamp = $dtStart.AddHours(1)
                SubscriptionId = 'sub-1'
                Status = [pscustomobject]@{ Value = 'Failed' }
                ResourceId = '/subscriptions/sub-1/providers/Microsoft.Compute/virtualMachines/vm1'
                CorrelationId = 'corr-1'
            }

            Mock Set-AzContext { }
            Mock Get-AzActivityLog { return @($objFailedRecord) }

            # Act
            $arrResult = @(Get-AzActivityAdminEvent -Start $dtStart -End $dtEnd -SubscriptionIds $arrSubscriptionIds -InitialSliceHours 25)

            # Assert
            $arrResult.Count | Should -Be 0
        }
    }

    Context "When given multiple subscriptions" {
        It "Calls Set-AzContext once per subscription ID" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $arrSubscriptionIds = @('sub-1', 'sub-2')

            Mock Set-AzContext { }
            Mock Get-AzActivityLog { return @() }

            # Act
            $null = @(Get-AzActivityAdminEvent -Start $dtStart -End $dtEnd -SubscriptionIds $arrSubscriptionIds -InitialSliceHours 25)

            # Assert
            Should -Invoke Set-AzContext -Times 2 -Exactly
        }
    }

    Context "When Set-AzContext emits benign probing warnings" {
        It "Suppresses Set-AzContext warnings from surfacing to the caller" {
            # Arrange
            # Simulate the Az.Accounts SharedTokenCacheCredential chain
            # behavior: Set-AzContext emits Write-Warning during credential
            # probing but eventually succeeds. The caller should not see
            # these warnings because Get-AzActivityAdminEvent passes
            # -WarningAction SilentlyContinue to Set-AzContext. The test
            # does NOT pass -WarningAction on the outer call, so if the
            # suppression inside the function were missing, the mock's
            # Write-Warning would bubble up into -WarningVariable.
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $arrSubscriptionIds = @('sub-1')

            Mock Set-AzContext {
                Write-Warning "Unable to acquire token for tenant '' with error 'SharedTokenCacheCredential authentication failed: '"
            }
            Mock Get-AzActivityLog { return @() }

            # Act: collect warnings surfaced from within the function.
            $arrWarnings = @()
            $null = @(Get-AzActivityAdminEvent -Start $dtStart -End $dtEnd -SubscriptionIds $arrSubscriptionIds -InitialSliceHours 25 -WarningVariable arrWarnings)

            # Assert
            $arrWarnings.Count | Should -Be 0
        }

        It "Still calls Set-AzContext even when it would emit warnings" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $arrSubscriptionIds = @('sub-1', 'sub-2', 'sub-3')

            Mock Set-AzContext {
                Write-Warning "Unable to acquire token for tenant '' with error 'SharedTokenCacheCredential authentication failed: '"
            }
            Mock Get-AzActivityLog { return @() }

            # Act
            $null = @(Get-AzActivityAdminEvent -Start $dtStart -End $dtEnd -SubscriptionIds $arrSubscriptionIds -InitialSliceHours 25)

            # Assert
            Should -Invoke Set-AzContext -Times 3 -Exactly
        }
    }

    Context "When Set-AzContext fails" {
        It "Emits a Write-Error and continues to the next subscription" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $arrSubscriptionIds = @('sub-fail', 'sub-ok')

            $objMockRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-1","http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn":"user@example.com"}'
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Compute/virtualMachines/write' }
                OperationName = [pscustomobject]@{ Value = 'Microsoft.Compute/virtualMachines/write' }
                Caller = 'user@example.com'
                EventTimestamp = $dtStart.AddHours(1)
                SubscriptionId = 'sub-ok'
                Status = [pscustomobject]@{ Value = 'Succeeded' }
                ResourceId = '/subscriptions/sub-ok/providers/Microsoft.Compute/virtualMachines/vm1'
                CorrelationId = 'corr-1'
            }

            Mock Set-AzContext {
                if ($SubscriptionId -eq 'sub-fail') {
                    throw 'Context switch failed'
                }
            }
            Mock Get-AzActivityLog { return @($objMockRecord) }

            # Act
            $arrResult = @(Get-AzActivityAdminEvent -Start $dtStart -End $dtEnd -SubscriptionIds $arrSubscriptionIds -InitialSliceHours 25 -ErrorAction SilentlyContinue)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].PrincipalKey | Should -Be 'oid-1'
        }
    }

    Context "When Get-AzActivityLog fails" {
        It "Emits a Write-Warning and continues to the next time segment" {
            # Arrange
            # Use a deterministic 48-hour window so the 24-hour slicing logic
            # produces exactly two segments. Deriving $dtEnd from $dtStart
            # avoids the sub-second drift introduced by two separate Get-Date
            # calls, which would otherwise create a third tiny slice.
            $dtStart = (Get-Date).AddDays(-2)
            $dtEnd = $dtStart.AddDays(2)
            $arrSubscriptionIds = @('sub-1')

            $script:intCallCount = 0
            Mock Set-AzContext { }
            Mock Get-AzActivityLog {
                $script:intCallCount++
                if ($script:intCallCount -eq 1) {
                    throw 'Activity log query failed'
                }
                return @()
            }

            # Act
            $null = @(Get-AzActivityAdminEvent -Start $dtStart -End $dtEnd -SubscriptionIds $arrSubscriptionIds -InitialSliceHours 24 -WarningAction SilentlyContinue)

            # Assert
            Should -Invoke Get-AzActivityLog -Times 2 -Exactly
        }
    }

    Context "When adaptive time subdivision is triggered" {
        It "Subdivides the time window when record count meets MaxRecordHint" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $arrSubscriptionIds = @('sub-1')
            $intMaxRecordHint = 3

            $objMockRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-1","http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn":"user@example.com"}'
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Compute/virtualMachines/write' }
                OperationName = [pscustomobject]@{ Value = 'Microsoft.Compute/virtualMachines/write' }
                Caller = 'user@example.com'
                EventTimestamp = $dtStart.AddHours(1)
                SubscriptionId = 'sub-1'
                Status = [pscustomobject]@{ Value = 'Succeeded' }
                ResourceId = '/subscriptions/sub-1/providers/Microsoft.Compute/virtualMachines/vm1'
                CorrelationId = 'corr-1'
            }

            $script:intCallCount = 0
            Mock Set-AzContext { }
            Mock Get-AzActivityLog {
                $script:intCallCount++
                if ($script:intCallCount -eq 1) {
                    # Return exactly MaxRecordHint records to trigger subdivision
                    return @($objMockRecord, $objMockRecord, $objMockRecord)
                }
                # Subsequent calls return fewer records
                return @($objMockRecord)
            }

            # Act
            $arrResult = @(Get-AzActivityAdminEvent -Start $dtStart -End $dtEnd -SubscriptionIds $arrSubscriptionIds -InitialSliceHours 25 -MaxRecordHint $intMaxRecordHint)

            # Assert
            $arrResult.Count | Should -BeGreaterThan 0
            Should -Invoke Get-AzActivityLog -Times 3 -Exactly
        }
    }

    Context "When DetailedOutput switch is specified" {
        It "Passes DetailedOutput to Get-AzActivityLog" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $arrSubscriptionIds = @('sub-1')

            Mock Set-AzContext { }
            Mock Get-AzActivityLog { return @() }

            # Act
            $null = @(Get-AzActivityAdminEvent -Start $dtStart -End $dtEnd -SubscriptionIds $arrSubscriptionIds -InitialSliceHours 25 -DetailedOutput)

            # Assert
            Should -Invoke Get-AzActivityLog -Times 1 -Exactly -ParameterFilter { $DetailedOutput -eq $true }
        }
    }

    Context "When Get-AzActivityLog returns an empty result" {
        It "Returns an empty array" {
            # Arrange
            $dtStart = (Get-Date).AddDays(-1)
            $dtEnd = Get-Date
            $arrSubscriptionIds = @('sub-1')

            Mock Set-AzContext { }
            Mock Get-AzActivityLog { return @() }

            # Act
            $arrResult = @(Get-AzActivityAdminEvent -Start $dtStart -End $dtEnd -SubscriptionIds $arrSubscriptionIds -InitialSliceHours 25)

            # Assert
            $arrResult.Count | Should -Be 0
        }
    }
}
