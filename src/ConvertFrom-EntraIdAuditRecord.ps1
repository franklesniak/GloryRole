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
    # .PARAMETER UnmappedActivityAccumulator
    # Optional. A [hashtable] reference that, when provided, receives
    # entries for each unmapped Entra ID activity this function declines
    # to emit **because the mapping returned $null** (i.e., the record
    # otherwise passed the success and principal eligibility checks).
    # Keys are "ActivityDisplayName|Category" composite strings. Values
    # are PSCustomObjects with ActivityDisplayName, Category, Count,
    # SampleCorrelationId, and SampleRecordId properties. The caller
    # creates the hashtable and passes it in; this function populates
    # it as a side effect. Records skipped for other reasons (non-success
    # result, unresolved principal, missing/unparseable ActivityDateTime)
    # are NOT tracked so the unmapped count reflects true mapping-table
    # coverage gaps rather than data-quality skips.
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
    # strings returned by that function are already canonical
    # microsoft.directory/* resource action paths (preserving the
    # camelCase segments of the published Entra ID / Microsoft Graph
    # role-permission namespace, such as oAuth2PermissionGrants and
    # administrativeUnits), so no additional normalization via
    # ConvertTo-NormalizedAction is performed.
    #
    # Supported on Windows PowerShell 5.1 (.NET Framework 4.6.2+) and
    # PowerShell 7.4.x / 7.5.x / 7.6.x (Windows, macOS, Linux).
    #
    # This function supports positional parameters:
    #   Position 0: Record
    #
    # Version: 1.1.20260418.0

    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [object]$Record,

        [hashtable]$UnmappedActivityAccumulator
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

            # Collect activity and category for the mapping step below.
            $strActivityDisplayName = $null
            if ($null -ne $Record.ActivityDisplayName) {
                $strActivityDisplayName = [string]$Record.ActivityDisplayName
            }

            $strCategory = $null
            if ($null -ne $Record.Category) {
                $strCategory = [string]$Record.Category
            }

            # Parse ActivityDateTime BEFORE the mapping check so that
            # records with missing/unparseable timestamps are dropped
            # without being counted as unmapped activities. The DC-6
            # contract requires TimeGenerated to be a [datetime] so that
            # downstream consumers (e.g., Sort-Object TimeGenerated in
            # Remove-DuplicateCanonicalEvent) can compare values. Graph
            # records may expose ActivityDateTime as a [datetime],
            # [datetimeoffset], or ISO-8601 string depending on
            # deserialization path, so normalize to UTC [datetime]
            # here and drop records whose timestamp cannot be parsed.
            $objDateTimeGenerated = $null
            if ($null -eq $Record.ActivityDateTime) {
                if ($boolVerbose) {
                    Write-Verbose "Dropping record because ActivityDateTime is missing."
                }

                return $null
            }

            if ($Record.ActivityDateTime -is [datetimeoffset]) {
                $objDateTimeGenerated = $Record.ActivityDateTime.UtcDateTime
            } elseif ($Record.ActivityDateTime -is [datetime]) {
                $objDateTimeGenerated = $Record.ActivityDateTime.ToUniversalTime()
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

                $objDateTimeGenerated = $objParsedActivityDateTimeOffset.UtcDateTime
            }

            # Map activity to a microsoft.directory/* resource action.
            # A $null/whitespace result means the activity is not in the
            # mapping table. At this point the record has already passed
            # success, principal, and date checks, so the ONLY remaining
            # reason for a $null emission is a mapping-table coverage
            # gap. That makes this the correct place to track the
            # unmapped activity in the caller-provided accumulator.
            $strAction = ConvertTo-EntraIdResourceAction -ActivityDisplayName $strActivityDisplayName -Category $strCategory
            if ([string]::IsNullOrWhiteSpace($strAction)) {
                if ($boolVerbose) {
                    Write-Verbose "Action is null or whitespace after mapping; returning null."
                }

                if ($null -ne $UnmappedActivityAccumulator -and
                    -not [string]::IsNullOrWhiteSpace($strActivityDisplayName)) {

                    $strAccKey = ("{0}|{1}" -f $strActivityDisplayName.Trim(), [string]$strCategory)
                    if ($UnmappedActivityAccumulator.ContainsKey($strAccKey)) {
                        $UnmappedActivityAccumulator[$strAccKey].Count++
                    } else {
                        $strSampleCorrelation = ''
                        if ($null -ne $Record.CorrelationId) {
                            $strSampleCorrelation = [string]$Record.CorrelationId
                        }
                        $strSampleRecordId = ''
                        if ($null -ne $Record.Id) {
                            $strSampleRecordId = [string]$Record.Id
                        }
                        $UnmappedActivityAccumulator[$strAccKey] = [pscustomobject]@{
                            ActivityDisplayName = $strActivityDisplayName.Trim()
                            Category = [string]$strCategory
                            Count = 1
                            SampleCorrelationId = $strSampleCorrelation
                            SampleRecordId = $strSampleRecordId
                        }
                    }
                }

                return $null
            }
            if ($boolVerbose) {
                Write-Verbose ("Mapped action: {0}" -f $strAction)
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
                TimeGenerated = $objDateTimeGenerated
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
