BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertFrom-ClaimsJson.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Resolve-PrincipalKey.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Resolve-LocalizableStringValue.ps1')
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

    # The following contexts cover the Az.Monitor 7.0.0 output shape, where
    # Status and OperationName are emitted as plain [string] values rather
    # than PSLocalizedString objects with .Value / .LocalizedValue.
    Context "When the record uses the Az.Monitor 7 plain-string Status shape" {
        It "Reads Status as a plain string and still emits a CanonicalAdminEvent" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-v7"}'
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Authorization/roleAssignments/delete' }
                OperationName = 'Delete role assignment'
                Caller = '4555631e-1459-47a7-bf60-b53ebc3670e4'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-v7'
                Status = 'Succeeded'
                ResourceId = '/subscriptions/sub-v7/providers/Microsoft.Authorization/roleAssignments/ra-1'
                CorrelationId = 'corr-v7'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult | Should -Not -BeNullOrEmpty
            $objResult.Status | Should -Be 'Succeeded'
            $objResult.Action | Should -Be 'microsoft.authorization/roleassignments/delete'
        }
    }

    Context "When Status exposes only LocalizedValue" {
        It "Falls back to LocalizedValue when Value is absent" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-loc"}'
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Storage/storageAccounts/read' }
                OperationName = $null
                Caller = 'user@example.com'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-loc'
                Status = [pscustomobject]@{ LocalizedValue = 'Succeeded' }
                ResourceId = '/subscriptions/sub-loc'
                CorrelationId = 'corr-loc'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult.Status | Should -Be 'Succeeded'
        }
    }

    Context "When Status is null" {
        It "Emits a CanonicalAdminEvent with Status = `$null without throwing" {
            # Arrange
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-nostatus"}'
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Resources/subscriptions/read' }
                OperationName = $null
                Caller = 'user@example.com'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-nostatus'
                Status = $null
                ResourceId = '/subscriptions/sub-nostatus'
                CorrelationId = 'corr-nostatus'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult | Should -Not -BeNullOrEmpty
            $objResult.Status | Should -Be $null
        }
    }

    Context "When Authorization is null and OperationName is the Az.Monitor 7 friendly display name" {
        It "Returns null rather than using a non-action display name" {
            # Arrange
            # In Az.Monitor 7+, OperationName carries the friendly display
            # name ("Delete role assignment") instead of an RBAC action id.
            # Feeding that into the clustering pipeline as if it were an
            # action would produce garbage, so records without a usable
            # Authorization.Action MUST be dropped.
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-display"}'
                Authorization = $null
                OperationName = 'Delete role assignment'
                Caller = 'user@example.com'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-display'
                Status = 'Succeeded'
                ResourceId = '/subscriptions/sub-display'
                CorrelationId = 'corr-display'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult | Should -Be $null
        }
    }

    Context "When Claims is an IDictionary (Az.Monitor 7+ shape)" {
        It "Extracts ObjectId from a hashtable-shaped claims bag" {
            # Arrange
            # Az.Monitor 7+ may expose Claims as IDictionary<string,string>
            # rather than a JSON string. A Hashtable is the closest
            # in-process representation for that shape.
            $htClaims = @{
                'http://schemas.microsoft.com/identity/claims/objectidentifier' = 'oid-dict-1'
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn' = 'dict-user@example.com'
                'appid' = 'app-dict-1'
            }
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = $htClaims
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Compute/virtualMachines/write' }
                OperationName = $null
                Caller = 'dict-user@example.com'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-dict'
                Status = 'Succeeded'
                ResourceId = '/subscriptions/sub-dict'
                CorrelationId = 'corr-dict-1'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult.PrincipalKey | Should -Be 'oid-dict-1'
            $objResult.PrincipalType | Should -Be 'User'
            $objResult.PrincipalUPN | Should -Be 'dict-user@example.com'
            $objResult.AppId | Should -Be 'app-dict-1'
        }

        It "Extracts AppId via the applicationid claim URI when lowercase appid is absent" {
            # Arrange
            $htClaims = @{
                'http://schemas.microsoft.com/identity/claims/applicationid' = 'app-uri-1'
            }
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = $htClaims
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Storage/storageAccounts/listKeys/action' }
                OperationName = $null
                Caller = 'service-principal'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-uri'
                Status = 'Succeeded'
                ResourceId = '/subscriptions/sub-uri'
                CorrelationId = 'corr-uri-1'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult.PrincipalKey | Should -Be 'app-uri-1'
            $objResult.PrincipalType | Should -Be 'ServicePrincipal'
            $objResult.AppId | Should -Be 'app-uri-1'
        }
    }

    Context "When Claims is a single DictionaryEntry (PSDictionaryElement flatten)" {
        It "Extracts the claim from a DictionaryEntry with the ObjectId key" {
            # Arrange
            # Reproduces the Az.Monitor 7+ path where PowerShell flattens a
            # one-entry IEnumerable<KeyValuePair> at parameter binding,
            # leaving Claims as a single DictionaryEntry. Previously this
            # shape silently discarded all claim values, forcing every
            # event to fall back to Caller-based "Unknown" resolution.
            $objEntry = New-Object System.Collections.DictionaryEntry(
                'http://schemas.microsoft.com/identity/claims/objectidentifier',
                'oid-entry-1'
            )
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = $objEntry
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Authorization/roleAssignments/write' }
                OperationName = $null
                Caller = 'some-caller'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-entry'
                Status = 'Succeeded'
                ResourceId = '/subscriptions/sub-entry'
                CorrelationId = 'corr-entry-1'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult.PrincipalKey | Should -Be 'oid-entry-1'
            $objResult.PrincipalType | Should -Be 'User'
        }

        It "Extracts AppId from a DictionaryEntry with the appid key" {
            # Arrange
            $objEntry = New-Object System.Collections.DictionaryEntry('appid', 'app-entry-1')
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = $objEntry
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Storage/storageAccounts/listKeys/action' }
                OperationName = $null
                Caller = 'some-caller'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-entry-app'
                Status = 'Succeeded'
                ResourceId = '/subscriptions/sub-entry-app'
                CorrelationId = 'corr-entry-app'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult.PrincipalKey | Should -Be 'app-entry-1'
            $objResult.PrincipalType | Should -Be 'ServicePrincipal'
            $objResult.AppId | Should -Be 'app-entry-1'
        }

        It "Falls back to Caller when the DictionaryEntry key is unknown" {
            # Arrange
            # When the single flattened entry is not one of the claim names
            # we recognize, Caller-based resolution remains the correct
            # fallback. This confirms the fix is additive, not destructive.
            $objEntry = New-Object System.Collections.DictionaryEntry('some-unrelated-claim', 'value')
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = $objEntry
                Authorization = [pscustomobject]@{ Action = 'Microsoft.Resources/subscriptions/read' }
                OperationName = $null
                Caller = 'caller-fallback@example.com'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-fallback'
                Status = 'Succeeded'
                ResourceId = '/subscriptions/sub-fallback'
                CorrelationId = 'corr-fallback'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult.PrincipalKey | Should -Be 'caller-fallback@example.com'
            $objResult.PrincipalType | Should -Be 'Unknown'
        }
    }

    Context "When Authorization is null and OperationName is a plain-string action id" {
        It "Accepts the plain-string OperationName as the action" {
            # Arrange
            # Az.Monitor 7 still returns a plain [string] for OperationName;
            # when that string happens to look like an RBAC action id
            # (contains '/'), it is a valid fallback.
            $objRecord = [pscustomobject]@{
                Category = 'Administrative'
                Claims = '{"http://schemas.microsoft.com/identity/claims/objectidentifier":"oid-plain"}'
                Authorization = $null
                OperationName = 'Microsoft.Resources/subscriptions/read'
                Caller = 'user@example.com'
                EventTimestamp = (Get-Date)
                SubscriptionId = 'sub-plain'
                Status = 'Succeeded'
                ResourceId = '/subscriptions/sub-plain'
                CorrelationId = 'corr-plain'
            }

            # Act
            $objResult = ConvertFrom-AzActivityLogRecord -Record $objRecord

            # Assert
            $objResult.Action | Should -Be 'microsoft.resources/subscriptions/read'
        }
    }
}
