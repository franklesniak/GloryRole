Set-StrictMode -Version Latest

function ConvertFrom-AzActivityLogRecord {
    # .SYNOPSIS
    # Converts a raw Azure Activity Log record to a canonical admin event.
    # .DESCRIPTION
    # Transforms a single record from Get-AzActivityLog into the
    # CanonicalAdminEvent contract. Filters to Administrative category only.
    # Returns $null if the record does not qualify (wrong category, missing
    # principal, or missing action).
    # .PARAMETER Record
    # A single record object from Get-AzActivityLog output.
    # .EXAMPLE
    # $objEvent = ConvertFrom-AzActivityLogRecord -Record $arrLogs[0]
    # # Returns a CanonicalAdminEvent PSCustomObject or $null.
    # .EXAMPLE
    # $objRecord = [pscustomobject]@{ Category = 'Policy'; Claims = $null; Authorization = $null; OperationName = $null; Caller = ''; EventTimestamp = (Get-Date); SubscriptionId = 'sub-1'; Status = [pscustomobject]@{ Value = 'Succeeded' }; ResourceId = '/subscriptions/sub-1'; CorrelationId = 'corr-1' }
    # $objEvent = ConvertFrom-AzActivityLogRecord -Record $objRecord
    # # Returns $null because category is not 'Administrative'.
    # .EXAMPLE
    # $objRecord = [pscustomobject]@{ Category = 'Administrative'; Claims = '{"appid":"app-789"}'; Authorization = [pscustomobject]@{ Action = 'Microsoft.Compute/virtualMachines/read' }; OperationName = $null; Caller = 'app-789'; EventTimestamp = (Get-Date); SubscriptionId = 'sub-1'; Status = [pscustomobject]@{ Value = 'Succeeded' }; ResourceId = '/subscriptions/sub-1/providers/Microsoft.Compute/virtualMachines/vm1'; CorrelationId = 'corr-2' }
    # $objEvent = ConvertFrom-AzActivityLogRecord -Record $objRecord
    # # Returns a CanonicalAdminEvent for a service-principal-based event
    # # where claims contain an appid but no UPN.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] A CanonicalAdminEvent object with PSTypeName
    # 'CanonicalAdminEvent', or $null when any of the following conditions
    # are met:
    # - The record's Category is not 'Administrative'.
    # - The principal cannot be resolved (no ObjectId, AppId, or Caller).
    # - The action string is null or whitespace after normalization.
    # .NOTES
    # Requires ConvertFrom-ClaimsJson, Resolve-PrincipalKey, and
    # ConvertTo-NormalizedAction to be loaded.
    #
    # Supported on Windows PowerShell 5.1 (.NET Framework 4.6.2+) and
    # PowerShell 7.4.x / 7.5.x / 7.6.x (Windows, macOS, Linux).
    #
    # This function supports positional parameters:
    #   Position 0: Record
    #
    # Version: 1.1.20260412.0

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Record
    )

    process {
        $boolVerbose = $PSBoundParameters.ContainsKey('Verbose') -or $VerbosePreference -ne 'SilentlyContinue'
        try {
            if ($Record.Category -ne 'Administrative') {
                if ($boolVerbose) {
                    Write-Verbose "Skipping non-Administrative record."
                }
                return $null
            }

            $objClaims = ConvertFrom-ClaimsJson -Claims $Record.Claims

            $strObjectId = $null
            $strUpn = $null
            $strAppId = $null
            if ($null -ne $objClaims) {
                if ($boolVerbose) {
                    Write-Verbose "Claims parsed successfully."
                }
                # Under Set-StrictMode -Version Latest, accessing a missing
                # property on a pscustomobject throws. Each claim below may be
                # absent from the JSON, so we probe PSObject.Properties first.
                if ($null -ne $objClaims.PSObject -and $null -ne $objClaims.PSObject.Properties) {
                    $strObjectIdClaim = 'http://schemas.microsoft.com/identity/claims/objectidentifier'
                    if ($objClaims.PSObject.Properties[$strObjectIdClaim]) {
                        $strObjectId = $objClaims.$strObjectIdClaim
                    }
                    $strUpnClaim = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn'
                    if ($objClaims.PSObject.Properties[$strUpnClaim]) {
                        $strUpn = $objClaims.$strUpnClaim
                    }
                    if ($objClaims.PSObject.Properties['appid']) {
                        $strAppId = $objClaims.appid
                    }
                }
            } else {
                if ($boolVerbose) {
                    Write-Verbose "Claims are null; skipping claims extraction."
                }
            }

            $objPrincipal = Resolve-PrincipalKey -ObjectId $strObjectId -AppId $strAppId -Caller $Record.Caller
            if ($null -eq $objPrincipal) {
                if ($boolVerbose) {
                    Write-Verbose "Principal resolution failed; returning null."
                }
                return $null
            }
            if ($boolVerbose) {
                Write-Verbose ("Resolved principal type: {0}" -f $objPrincipal.Type)
            }

            $strActionRaw = $null
            if ($null -ne $Record.Authorization -and $null -ne $Record.Authorization.Action) {
                $strActionRaw = [string]$Record.Authorization.Action
            } elseif ($null -ne $Record.OperationName -and $null -ne $Record.OperationName.Value) {
                $strActionRaw = [string]$Record.OperationName.Value
            }

            $strAction = ConvertTo-NormalizedAction -Action $strActionRaw
            if ([string]::IsNullOrWhiteSpace($strAction)) {
                if ($boolVerbose) {
                    Write-Verbose "Action is null or whitespace after normalization; returning null."
                }
                return $null
            }
            if ($boolVerbose) {
                Write-Verbose ("Normalized action: {0}" -f $strAction)
            }

            if ($boolVerbose) {
                Write-Verbose "Emitting CanonicalAdminEvent object."
            }
            [pscustomobject]@{
                PSTypeName = 'CanonicalAdminEvent'
                TimeGenerated = $Record.EventTimestamp
                SubscriptionId = $Record.SubscriptionId
                PrincipalKey = [string]$objPrincipal.Key
                PrincipalType = [string]$objPrincipal.Type
                Action = $strAction
                Status = $Record.Status.Value
                ResourceId = $Record.ResourceId
                CorrelationId = $Record.CorrelationId
                Caller = $Record.Caller
                PrincipalUPN = $strUpn
                AppId = $strAppId
            }
        } catch {
            Write-Debug ("ConvertFrom-AzActivityLogRecord failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
