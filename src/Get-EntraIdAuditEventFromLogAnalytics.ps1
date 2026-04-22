Set-StrictMode -Version Latest

function Get-EntraIdAuditEventFromLogAnalytics {
    # .SYNOPSIS
    # Collects canonical Entra ID admin events from a Log Analytics
    # workspace that receives Entra ID directory audit logs.
    # .DESCRIPTION
    # Queries the AuditLogs table in a Log Analytics workspace for
    # successful Entra ID directory audit records within the specified
    # time range. Extracts the initiating principal from the
    # InitiatedBy JSON column, maps each activity display name to a
    # microsoft.directory/* resource action via
    # ConvertTo-EntraIdResourceAction, and streams
    # CanonicalEntraIdEvent objects to the pipeline.
    #
    # This function is the Log Analytics counterpart of
    # Get-EntraIdAuditEvent (which queries Microsoft Graph directly).
    # Both produce the same CanonicalEntraIdEvent output contract so
    # the downstream pipeline (deduplication, display-name mapping,
    # aggregation, clustering) works identically regardless of the
    # data source.
    #
    # The heavy lifting (date-range filtering, success filtering,
    # principal extraction, and retry-duplicate collapse) is performed
    # server-side in KQL so that only qualifying rows travel over the
    # wire. Retry duplicates are collapsed server-side on the composite
    # key (PrincipalKey, OperationName, CorrelationId) using
    # arg_min(TimeGenerated, ...) so the earliest row per composite key
    # is retained; rows whose CorrelationId is missing (null, empty, or
    # whitespace-only after trimming) are preserved via a union branch
    # because they cannot be retry-duplicates (the CorrelationId is
    # required to identify a retry pair). "Missing" is defined
    # consistently with REQ-DED-001 and Remove-DuplicateCanonicalEvent's
    # [string]::IsNullOrWhiteSpace contract, so the KQL derives a
    # CorrelationIdNormalized = trim(@"\s+", ...) column that is used
    # only for the isnotempty/isempty split. The summarize key and the
    # emitted CorrelationId value remain the raw CorrelationId so that
    # non-missing padded values (e.g. " abc " vs. "abc") stay distinct,
    # matching Remove-DuplicateCanonicalEvent's raw-string key. The
    # activity-to-action mapping is performed PowerShell-side via
    # ConvertTo-EntraIdResourceAction because the mapping table is
    # maintained in PowerShell and embedding 150+ entries in KQL would
    # be fragile.
    #
    # Two distinct failure modes apply to individual records:
    # - **Intentional skips.** Records whose activity display name
    #   does not map to a microsoft.directory/* action (e.g.,
    #   self-service events, informational entries) are silently
    #   skipped and counted in the verbose "Records skipped" tally.
    # - **Exceptions.** Terminating errors from
    #   Invoke-AzOperationalInsightsQuery (e.g., network failures,
    #   authorization errors) are always propagated to the caller.
    # .PARAMETER WorkspaceId
    # The Log Analytics workspace ID to query. The workspace must
    # receive Entra ID directory audit logs via diagnostic settings.
    # .PARAMETER Start
    # The start of the time range to query.
    # .PARAMETER End
    # The end of the time range to query.
    # .PARAMETER FilterCategory
    # Optional. One or more audit log categories to filter by (e.g.,
    # 'GroupManagement', 'UserManagement', 'RoleManagement'). When
    # specified, only records matching these categories are retrieved
    # via the KQL query. When omitted, all categories are returned.
    # .PARAMETER UnmappedActivityAccumulator
    # Optional. A [hashtable] reference that, when provided, receives
    # entries for each unmapped Entra ID activity encountered during
    # ingestion. Keys are "ActivityDisplayName|Category" composite
    # strings. Values are PSCustomObjects with ActivityDisplayName,
    # Category, Count, SampleCorrelationId, and SampleRecordId
    # properties. The caller creates the hashtable and passes it in;
    # this function populates it as a side effect. When omitted,
    # unmapped activities are silently skipped as before.
    # .EXAMPLE
    # $arrEvents = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId '12345678-1234-1234-1234-123456789012' -Start (Get-Date).AddDays(-30) -End (Get-Date))
    # # Retrieves all successful Entra ID admin events for the last
    # # 30 days from the specified Log Analytics workspace and wraps
    # # the call in @() to guarantee an array result.
    # .EXAMPLE
    # $arrEvents = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId '12345678-1234-1234-1234-123456789012' -Start (Get-Date).AddDays(-7) -End (Get-Date) -FilterCategory @('GroupManagement', 'UserManagement'))
    # # Retrieves only GroupManagement and UserManagement events from
    # # the last 7 days in the specified workspace.
    # .EXAMPLE
    # $hashUnmapped = @{}
    # $arrEvents = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId '12345678-1234-1234-1234-123456789012' -Start (Get-Date).AddDays(-30) -End (Get-Date) -UnmappedActivityAccumulator $hashUnmapped)
    # # $hashUnmapped now contains entries for each unmapped activity
    # # with Count, Category, and sample IDs for diagnostics.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] CanonicalEntraIdEvent objects streamed to the
    # pipeline.
    # .NOTES
    # Requires Az.OperationalInsights module.
    # Requires ConvertTo-EntraIdResourceAction to be loaded.
    #
    # Supported on Windows PowerShell 5.1 (.NET Framework 4.6.2+) and
    # PowerShell 7.4.x / 7.5.x / 7.6.x (Windows, macOS, Linux).
    #
    # This function supports positional parameters:
    #   Position 0: WorkspaceId
    #   Position 1: Start
    #   Position 2: End
    #
    # Version: 1.5.20260422.0

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = '"LogAnalytics" here is the proper name of the Azure Log Analytics service, not a plural noun; renaming would obscure the function''s target service.')]
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$WorkspaceId,

        [Parameter(Mandatory = $true, Position = 1)]
        [datetime]$Start,

        [Parameter(Mandatory = $true, Position = 2)]
        [datetime]$End,

        [string[]]$FilterCategory,

        [hashtable]$UnmappedActivityAccumulator
    )

    process {
        try {
            Write-Verbose ("Querying AuditLogs table in workspace {0} from {1:yyyy-MM-ddTHH:mm:ssZ} to {2:yyyy-MM-ddTHH:mm:ssZ}..." -f $WorkspaceId, $Start.ToUniversalTime(), $End.ToUniversalTime())

            # Build KQL query. The AuditLogs table is populated when an
            # Entra ID tenant sends directory audit logs to a Log
            # Analytics workspace via diagnostic settings.
            #
            # Principal extraction mirrors ConvertFrom-EntraIdAuditRecord:
            # User.Id > App.AppId > App.DisplayName. Records with no
            # resolvable principal or no OperationName are excluded
            # server-side.
            #
            # Retry-duplicate collapse (Option A): after the `src`
            # projection, each row carries both the original
            # CorrelationId and a whitespace-normalized copy
            # (CorrelationIdNormalized = trim(@"\s+", ...)). The
            # normalized column is used ONLY for the isnotempty/isempty
            # split so that server-side and client-side pipelines agree
            # on which rows are "missing" a CorrelationId (null, empty,
            # or whitespace-only). Rows whose normalized CorrelationId
            # is non-empty are summarized with arg_min(TimeGenerated,
            # ...) by the composite key (PrincipalKey, OperationName,
            # CorrelationId) -- keyed on the RAW CorrelationId, not the
            # trimmed value -- so server-side collapse semantics match
            # Remove-DuplicateCanonicalEvent's raw-string composite key
            # (REQ-DED-001). project-rename restores the original
            # TimeGenerated column name. Rows whose normalized
            # CorrelationId is empty are unioned back unchanged --
            # keeping their raw CorrelationId -- because they cannot be
            # retry-duplicates of one another, and collapsing them
            # would violate the invariant that records without a usable
            # CorrelationId are always kept. The composite key
            # intentionally omits RecordId and TimeGenerated so that
            # retries (which differ only in those two fields and share
            # a CorrelationId) collapse to a single row, matching the
            # client-side Remove-DuplicateCanonicalEvent contract.
            $strCategoryFilter = ''
            if ($null -ne $FilterCategory -and $FilterCategory.Count -gt 0) {
                $arrCategoryParts = @()
                foreach ($strCat in $FilterCategory) {
                    if ([string]::IsNullOrWhiteSpace($strCat)) {
                        continue
                    }
                    # Escape single quotes for KQL string literals.
                    $strEscapedCat = $strCat.Replace("'", "''")
                    $arrCategoryParts += ("Category == '{0}'" -f $strEscapedCat)
                }
                if ($arrCategoryParts.Count -gt 0) {
                    $strCategoryFilter = ("| where {0}" -f ($arrCategoryParts -join ' or '))
                }
            }

            $strStartUtc = $Start.ToUniversalTime().ToString("o")
            $strEndUtc = $End.ToUniversalTime().ToString("o")

            $strKql = @"
let src =
    AuditLogs
    | where TimeGenerated between (datetime($strStartUtc) .. datetime($strEndUtc))
    | where ResultDescription =~ "success" or Result =~ "success"
    $strCategoryFilter
    | extend InitiatedByObj = parse_json(InitiatedBy)
    | extend UserId = tostring(InitiatedByObj.user.id)
    | extend UserUPN = tostring(InitiatedByObj.user.userPrincipalName)
    | extend AppIdVal = tostring(InitiatedByObj.app.appId)
    | extend AppDisplayName = tostring(InitiatedByObj.app.displayName)
    | extend PrincipalKey = case(
        isnotempty(UserId), UserId,
        isnotempty(AppIdVal), AppIdVal,
        isnotempty(AppDisplayName), AppDisplayName,
        ""
    )
    | extend PrincipalType = case(
        isnotempty(UserId), "User",
        isnotempty(AppIdVal) or isnotempty(AppDisplayName), "ServicePrincipal",
        "Unknown"
    )
    | extend CorrelationIdNormalized = trim(@"\s+", tostring(CorrelationId))
    | where isnotempty(PrincipalKey) and isnotempty(OperationName)
    | project TimeGenerated, OperationName, Category, PrincipalKey, PrincipalType, PrincipalUPN=UserUPN, AppId=AppIdVal, CorrelationId, CorrelationIdNormalized, RecordId=Id;
src
| where isnotempty(CorrelationIdNormalized)
| summarize arg_min(TimeGenerated, Category, PrincipalType, PrincipalUPN, AppId, RecordId) by PrincipalKey, OperationName, CorrelationId
| project-rename TimeGenerated = min_TimeGenerated
| project TimeGenerated, OperationName, Category, PrincipalKey, PrincipalType, PrincipalUPN, AppId, CorrelationId, RecordId
| union (src | where isempty(CorrelationIdNormalized) | project TimeGenerated, OperationName, Category, PrincipalKey, PrincipalType, PrincipalUPN, AppId, CorrelationId, RecordId)
"@

            Write-Debug ("KQL query: {0}" -f $strKql)

            $objVerbosePreferenceAtStartOfBlock = $VerbosePreference
            $objQueryResult = $null
            try {
                $VerbosePreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
                $objQueryResult = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $strKql -ErrorAction Stop
                $VerbosePreference = $objVerbosePreferenceAtStartOfBlock
            } catch {
                Write-Debug ("Log Analytics query failed: {0}" -f $_.Exception.Message)
                throw
            } finally {
                $VerbosePreference = $objVerbosePreferenceAtStartOfBlock
            }

            $arrRows = @($objQueryResult.Results)
            Write-Verbose ("  Rows returned from AuditLogs: {0}" -f $arrRows.Count)

            $intEmitted = 0
            $intSkipped = 0
            $intUnmapped = 0
            foreach ($objRow in $arrRows) {
                $strOperationName = [string]$objRow.OperationName
                $strCategory = $null
                if ($null -ne $objRow.Category) {
                    $strCategory = [string]$objRow.Category
                }

                # Parse TimeGenerated from the KQL result BEFORE the
                # mapping check so rows with missing/unparseable
                # timestamps are dropped without being counted as
                # unmapped activities. Log Analytics returns dates as
                # ISO-8601 strings; normalize to UTC [datetime] to
                # match the DC-6 contract.
                $objTimeGenerated = $null
                if ($null -ne $objRow.TimeGenerated) {
                    $strTimeGenerated = [string]$objRow.TimeGenerated
                    if (-not [string]::IsNullOrWhiteSpace($strTimeGenerated)) {
                        $objParsedOffset = [datetimeoffset]::MinValue
                        $boolParsed = [datetimeoffset]::TryParse(
                            $strTimeGenerated,
                            [System.Globalization.CultureInfo]::InvariantCulture,
                            [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal,
                            [ref]$objParsedOffset
                        )
                        if ($boolParsed) {
                            $objTimeGenerated = $objParsedOffset.UtcDateTime
                        }
                    }
                }

                if ($null -eq $objTimeGenerated) {
                    $intSkipped++
                    continue
                }

                # Map activity display name to a microsoft.directory/*
                # resource action. Unmapped activities return $null and
                # are silently skipped (same as Get-EntraIdAuditEvent).
                # At this point the row has already passed the KQL
                # success + principal + OperationName filters AND the
                # client-side TimeGenerated parse, so the ONLY
                # remaining reason for a $null/empty mapping is a true
                # mapping-table coverage gap.
                $strAction = ConvertTo-EntraIdResourceAction -ActivityDisplayName $strOperationName -Category $strCategory
                if ([string]::IsNullOrWhiteSpace($strAction)) {
                    $intSkipped++

                    # Track unmapped activities when an accumulator is
                    # provided.
                    if ($null -ne $UnmappedActivityAccumulator -and
                        -not [string]::IsNullOrWhiteSpace($strOperationName)) {

                        $intUnmapped++
                        $strAccKey = ("{0}|{1}" -f $strOperationName.Trim(), $strCategory)
                        if ($UnmappedActivityAccumulator.ContainsKey($strAccKey)) {
                            $UnmappedActivityAccumulator[$strAccKey].Count++
                        } else {
                            $strSampleCorrelation = ''
                            if ($null -ne $objRow.CorrelationId) {
                                $strSampleCorrelation = [string]$objRow.CorrelationId
                            }
                            $strSampleRecordId = ''
                            if ($null -ne $objRow.RecordId) {
                                $strSampleRecordId = [string]$objRow.RecordId
                            }
                            $UnmappedActivityAccumulator[$strAccKey] = [pscustomobject]@{
                                ActivityDisplayName = $strOperationName.Trim()
                                Category = $strCategory
                                Count = 1
                                SampleCorrelationId = $strSampleCorrelation
                                SampleRecordId = $strSampleRecordId
                            }
                        }
                    }

                    continue
                }

                $strCorrelationId = $null
                if ($null -ne $objRow.CorrelationId) {
                    $strCorrelationId = [string]$objRow.CorrelationId
                }

                $strRecordId = $null
                if ($null -ne $objRow.RecordId) {
                    $strRecordId = [string]$objRow.RecordId
                }

                $strPrincipalUPN = $null
                if (-not [string]::IsNullOrWhiteSpace([string]$objRow.PrincipalUPN)) {
                    $strPrincipalUPN = [string]$objRow.PrincipalUPN
                }

                $strAppId = $null
                if (-not [string]::IsNullOrWhiteSpace([string]$objRow.AppId)) {
                    $strAppId = [string]$objRow.AppId
                }

                $intEmitted++
                [pscustomobject]@{
                    PSTypeName = 'CanonicalEntraIdEvent'
                    TimeGenerated = $objTimeGenerated
                    PrincipalKey = [string]$objRow.PrincipalKey
                    PrincipalType = [string]$objRow.PrincipalType
                    Action = $strAction
                    Result = 'success'
                    Category = $strCategory
                    ActivityDisplayName = $strOperationName
                    CorrelationId = $strCorrelationId
                    RecordId = $strRecordId
                    PrincipalUPN = $strPrincipalUPN
                    AppId = $strAppId
                }
            }

            if ($intUnmapped -gt 0) {
                Write-Verbose ("  Unmapped activities: {0}" -f $intUnmapped)
            }
            Write-Verbose ("  Events emitted: {0}, Records skipped: {1}" -f $intEmitted, $intSkipped)
        } catch {
            Write-Debug ("Get-EntraIdAuditEventFromLogAnalytics failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
