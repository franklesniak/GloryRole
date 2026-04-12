BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertFrom-ClaimsJson.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Resolve-PrincipalKey.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-NormalizedAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertFrom-AzActivityLogRecord.ps1')
}

Describe "ConvertFrom-AzActivityLogRecord" {
    Context "When the record category is not Administrative" {
        It "Returns null for a non-Administrative category" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Category = 'Policy'
                Claims = $null
                Authorization = $null
                OperationName = $null
                Caller = ''
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-1'
                Status = [pscustomobject]@{ Value = 'Succeeded' }
                ResourceId = '/subscriptions/sub-1'
                CorrelationId = 'corr-1'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }
    }

    Context "When the principal cannot be resolved" {
        It "Returns null when claims are null and Caller is empty" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = $null
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Compute/virtualMachines/read' }
                OperationName = $null
                Caller = ''
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-1'
                Status = [pscustomobject]@{ Value = 'Succeeded' }
                ResourceId = '/subscriptions/sub-1'
                CorrelationId = 'corr-1'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }
    }

    Context "When the action is missing" {
        It "Returns null when Authorization and OperationName are both null" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-123","http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn":"user@example.com"}'
                Authorization = $null
                OperationName = $null
                Caller = 'user@example.com'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-1'
                Status = [pscustomobject]@{ Value = 'Succeeded' }
                ResourceId = '/subscriptions/sub-1'
                CorrelationId = 'corr-1'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }

        It "Returns null when action is whitespace-only" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-123","http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn":"user@example.com"}'
                Authorization = [pscustomobject]@{ Action = '   ' }
                OperationName = $null
                Caller = 'user@example.com'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-1'
                Status = [pscustomobject]@{ Value = 'Succeeded' }
                ResourceId = '/subscriptions/sub-1'
                CorrelationId = 'corr-1'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }
    }

    Context "When given a valid Administrative record" {
        It "Produces a CanonicalAdminEvent with correct properties" {
            # Arrange
            $dtTimestamp = Get-Date -Year 2026 -Month 3 -Day 19 -Hour 10 -Minute 0 -Second 0
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-abc","http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn":"admin@contoso.com","appid":"app-456"}'
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Compute/virtualMachines/write' }
                OperationName = [pscustomobject]@{ Value = 'Microsoft.Compute/virtualMachines/write' }
                Caller = 'admin@contoso.com'
                EventTimestamp = $dtTimestamp
                SubscriptionId = 'sub-abc'
                Status = [pscustomobject]@{ Value = 'Succeeded' }
                ResourceId = '/subscriptions/sub-abc/providers/Microsoft.Compute/virtualMachines/vm1'
                CorrelationId = 'corr-xyz'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult | Should -Not -BeNullOrEmpty
            $objResult.PSObject.TypeNames | Should -Contain 'CanonicalAdminEvent'
            $objResult.PrincipalKey | Should -Be 'oid-abc'
            $objResult.PrincipalType | Should -Be 'User'
            $objResult.Action | Should -Be 'microsoft.compute/virtualmachines/write'
            $objResult.Status | Should -Be 'Succeeded'
            $objResult.SubscriptionId | Should -Be 'sub-abc'
            $objResult.Caller | Should -Be 'admin@contoso.com'
            $objResult.PrincipalUPN | Should -Be 'admin@contoso.com'
            $objResult.AppId | Should -Be 'app-456'
            $objResult.CorrelationId | Should -Be 'corr-xyz'
            $objResult.TimeGenerated | Should -Be $dtTimestamp
            $objResult.ResourceId | Should -Be '/subscriptions/sub-abc/providers/Microsoft.Compute/virtualMachines/vm1'
        }
    }

    Context "When both Authorization.Action and OperationName.Value are present" {
        It "Prefers Authorization.Action over OperationName.Value" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-123"}'
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Storage/storageAccounts/write' }
                OperationName = [pscustomobject]@{ Value = 'Microsoft.Storage/storageAccounts/delete' }
                Caller = 'user@example.com'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-1'
                Status = [pscustomobject]@{ Value = 'Succeeded' }
                ResourceId = '/subscriptions/sub-1'
                CorrelationId = 'corr-1'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult.Action | Should -Be 'microsoft.storage/storageaccounts/write'
        }
    }

    Context "When Authorization is null" {
        It "Falls back to OperationName.Value for the action" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-123"}'
                Authorization = $null
                OperationName = [pscustomobject]@{ Value = 'Microsoft.Resources/subscriptions/read' }
                Caller = 'user@example.com'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-1'
                Status = [pscustomobject]@{ Value = 'Succeeded' }
                ResourceId = '/subscriptions/sub-1'
                CorrelationId = 'corr-1'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult.Action | Should -Be 'microsoft.resources/subscriptions/read'
        }
    }

    Context "When claims are null but Caller is provided" {
        It "Resolves the principal via the Caller fallback" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = $null
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Compute/virtualMachines/start/action' }
                OperationName = $null
                Caller = 'external-caller@partner.com'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-2'
                Status = [pscustomobject]@{ Value = 'Failed' }
                ResourceId = '/subscriptions/sub-2'
                CorrelationId = 'corr-3'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult | Should -Not -BeNullOrEmpty
            $objResult.PrincipalKey | Should -Be 'external-caller@partner.com'
            $objResult.PrincipalType | Should -Be 'Unknown'
            $objResult.Caller | Should -Be 'external-caller@partner.com'
            $objResult.PrincipalUPN | Should -Be $null
            $objResult.AppId | Should -Be $null
        }
    }
}
