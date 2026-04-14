Set-StrictMode -Version Latest

function ConvertFrom-EntraIdAuditRecord {
    # .SYNOPSIS
    # Converts a raw Microsoft Graph directory audit record to a canonical
    # Entra ID admin event.
    # .DESCRIPTION
    # Transforms a single record from Get-MgAuditLogDirectoryAudit into
    # the CanonicalEntraIdEvent contract. Filters to successful results
    # only. Returns $null if the record does not qualify (failure result,
    # missing principal, missing activity, or missing/unparseable
    # ActivityDateTime).
    #
    # The initiatedBy field is resolved using the precedence:
    # User.Id > App.AppId > App.DisplayName. Records with no resolvable
    # principal are dropped.
    #
    # The action is derived by mapping the ActivityDisplayName through
    # ConvertTo-EntraIdResourceAction to produce a
    # microsoft.directory/* permission string suitable for Entra ID
    # custom role definitions.
    # .PARAMETER Record
    # A single record object from Get-MgAuditLogDirectoryAudit output.
    # .EXAMPLE
    # $objEvent = ConvertFrom-EntraIdAuditRecord -Record $arrAudits[0]
    # # Returns a CanonicalEntraIdEvent PSCustomObject or $null.
    # .EXAMPLE
    # $objRecord = [pscustomobject]@{ Result = 'failure'; ActivityDisplayName = 'Add member to group'; Category = 'GroupManagement'; InitiatedBy = [pscustomobject]@{ User = [pscustomobject]@{ Id = 'user-1'; UserPrincipalName = 'admin@contoso.com' }; App = $null }; ActivityDateTime = (Get-Date); CorrelationId = 'corr-1'; Id = 'id-1' }
    # $objEvent = ConvertFrom-EntraIdAuditRecord -Record $objRecord
    # # Returns $null because result is not 'success'.
    # .EXAMPLE
    # $objRecord = [pscustomobject]@{ Result = 'success'; ActivityDisplayName = 'Add member to group'; Category = 'GroupManagement'; InitiatedBy = [pscustomobject]@{ User = [pscustomobject]@{ Id = 'user-1'; UserPrincipalName = 'admin@contoso.com' }; App = $null }; ActivityDateTime = (Get-Date); CorrelationId = 'corr-2'; Id = 'id-2' }
    # $objEvent = ConvertFrom-EntraIdAuditRecord -Record $objRecord
    # # Returns a CanonicalEntraIdEvent with PrincipalKey = 'user-1'
    # # and Action mapped to a microsoft.directory/* permission.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] A CanonicalEntraIdEvent object with PSTypeName
    # 'CanonicalEntraIdEvent', or $null when any of the following
    # conditions are met:
    # - The record's Result is not 'success'.
    # - The principal cannot be resolved (no User.Id, App.AppId, or
    #   App.DisplayName).
    # - The action string is null or whitespace after mapping.
    # - ActivityDateTime is missing or cannot be parsed as [datetime].
    # .NOTES
    # Requires ConvertTo-EntraIdResourceAction to be loaded. The action
    # strings returned by that function are already fully normalized
    # (lowercase microsoft.directory/* paths), so no additional
    # normalization via ConvertTo-NormalizedAction is performed.
    #
    # Supported on Windows PowerShell 5.1 (.NET Framework 4.6.2+) and
    # PowerShell 7.4.x / 7.5.x / 7.6.x (Windows, macOS, Linux).
    #
    # This function supports positional parameters:
    #   Position 0: Record
    #
    # Version: 1.0.20260414.1

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Record
    )

    process {
        $boolVerbose = $PSBoundParameters.ContainsKey('Verbose') -or $VerbosePreference -ne 'SilentlyContinue'
        try {
            # Filter to successful operations only
            $strResult = $null
            if ($null -ne $Record.Result) {
                $strResult = [string]$Record.Result
            }
            if ($strResult -ne 'success') {
                if ($boolVerbose) {
                    Write-Verbose ("Skipping non-success record (result={0})." -f $strResult)
                }
                return $null
            }

            # Resolve principal from InitiatedBy
            $strPrincipalKey = $null
            $strPrincipalType = $null
            $strUpn = $null
            $strAppId = $null

            if ($null -ne $Record.InitiatedBy) {
                $objInitiatedBy = $Record.InitiatedBy

                # Prefer User.Id (human user)
                if ($null -ne $objInitiatedBy.User -and
                    -not [string]::IsNullOrWhiteSpace($objInitiatedBy.User.Id)) {
                    $strPrincipalKey = [string]$objInitiatedBy.User.Id
                    $strPrincipalType = 'User'
                    if ($null -ne $objInitiatedBy.User.UserPrincipalName) {
                        $strUpn = [string]$objInitiatedBy.User.UserPrincipalName
                    }
                } elseif ($null -ne $objInitiatedBy.App) {
                    # Fall back to App.AppId
                    if (-not [string]::IsNullOrWhiteSpace($objInitiatedBy.App.AppId)) {
                        $strPrincipalKey = [string]$objInitiatedBy.App.AppId
                        $strPrincipalType = 'ServicePrincipal'
                        $strAppId = [string]$objInitiatedBy.App.AppId
                    } elseif (-not [string]::IsNullOrWhiteSpace($objInitiatedBy.App.DisplayName)) {
                        # Last resort: use app display name
                        $strPrincipalKey = [string]$objInitiatedBy.App.DisplayName
                        $strPrincipalType = 'ServicePrincipal'
                    }
                }
            }

            if ([string]::IsNullOrWhiteSpace($strPrincipalKey)) {
                if ($boolVerbose) {
                    Write-Verbose "Principal resolution failed; returning null."
                }
                return $null
            }
            if ($boolVerbose) {
                Write-Verbose ("Resolved principal type: {0}" -f $strPrincipalType)
            }

            # Map activity to a microsoft.directory/* resource action
            $strActivityDisplayName = $null
            if ($null -ne $Record.ActivityDisplayName) {
                $strActivityDisplayName = [string]$Record.ActivityDisplayName
            }

            $strCategory = $null
            if ($null -ne $Record.Category) {
                $strCategory = [string]$Record.Category
            }

            $strAction = ConvertTo-EntraIdResourceAction -ActivityDisplayName $strActivityDisplayName -Category $strCategory
            if ([string]::IsNullOrWhiteSpace($strAction)) {
                if ($boolVerbose) {
                    Write-Verbose "Action is null or whitespace after mapping; returning null."
                }
                return $null
            }
            if ($boolVerbose) {
                Write-Verbose ("Mapped action: {0}" -f $strAction)
            }

            # Build the canonical event object. The DC-6 contract
            # requires TimeGenerated to be a [datetime] so that
            # downstream consumers (e.g., Sort-Object TimeGenerated in
            # Remove-DuplicateCanonicalEvent) can compare values. Graph
            # records may expose ActivityDateTime as a [datetime],
            # [datetimeoffset], or ISO-8601 string depending on
            # deserialization path, so normalize to UTC [datetime]
            # here and drop records whose timestamp cannot be parsed.
            $dateTimeGenerated = $null
            if ($null -ne $Record.ActivityDateTime) {
                $objActivityDateTime = $Record.ActivityDateTime
                try {
                    if ($objActivityDateTime -is [datetime]) {
                        $dateTimeGenerated = ([datetime]$objActivityDateTime).ToUniversalTime()
                    } elseif ($objActivityDateTime -is [datetimeoffset]) {
                        $dateTimeGenerated = ([datetimeoffset]$objActivityDateTime).UtcDateTime
                    } else {
                        $dateTimeGenerated = ([datetime]::Parse([string]$objActivityDateTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal))
                    }
                } catch {
                    $dateTimeGenerated = $null
                }
            }
            if ($null -eq $dateTimeGenerated) {
                if ($boolVerbose) {
                    Write-Verbose "ActivityDateTime is missing or could not be parsed as [datetime]; returning null."
                }
                return $null
            }

            $dateTimeGenerated = $null
            if ($null -eq $Record.ActivityDateTime) {
                if ($boolVerbose) {
                    Write-Verbose "Dropping record because ActivityDateTime is missing."
                }

                return $null
            }

            if ($Record.ActivityDateTime -is [datetimeoffset]) {
                $dateTimeGenerated = $Record.ActivityDateTime.UtcDateTime
            } elseif ($Record.ActivityDateTime -is [datetime]) {
                $dateTimeGenerated = $Record.ActivityDateTime.ToUniversalTime()
            } else {
                $strActivityDateTime = [string]$Record.ActivityDateTime
                if ([string]::IsNullOrWhiteSpace($strActivityDateTime)) {
                    if ($boolVerbose) {
                        Write-Verbose "Dropping record because ActivityDateTime is empty."
                    }

                    return $null
                }

                $objParsedActivityDateTimeOffset = [datetimeoffset]::MinValue
                $boolParsedActivityDateTime = [datetimeoffset]::TryParse(
                    $strActivityDateTime,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal,
                    [ref]$objParsedActivityDateTimeOffset
                )
                if (-not $boolParsedActivityDateTime) {
                    if ($boolVerbose) {
                        Write-Verbose "Dropping record because ActivityDateTime could not be parsed."
                    }

                    return $null
                }

                $dateTimeGenerated = $objParsedActivityDateTimeOffset.UtcDateTime
            }

            $strCorrelationId = $null
            if ($null -ne $Record.CorrelationId) {
                $strCorrelationId = [string]$Record.CorrelationId
            }

            $strRecordId = $null
            if ($null -ne $Record.Id) {
                $strRecordId = [string]$Record.Id
            }

            if ($boolVerbose) {
                Write-Verbose "Emitting CanonicalEntraIdEvent object."
            }

            [pscustomobject]@{
                PSTypeName = 'CanonicalEntraIdEvent'
                TimeGenerated = $dateTimeGenerated
                PrincipalKey = $strPrincipalKey
                PrincipalType = $strPrincipalType
                Action = $strAction
                Result = $strResult
                Category = $strCategory
                ActivityDisplayName = $strActivityDisplayName
                CorrelationId = $strCorrelationId
                RecordId = $strRecordId
                PrincipalUPN = $strUpn
                AppId = $strAppId
            }
        } catch {
            Write-Debug ("ConvertFrom-EntraIdAuditRecord failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
