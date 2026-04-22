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
    # .PARAMETER EntraIdInitialSliceHours
    # Initial time-window chunk width in hours for partitioning the
    # KQL query. The [Start, End] range is broken into chunks of this
    # width, each issued as a separate query whose results are
    # concatenated client-side. Default is 24. This protects against
    # the documented Log Analytics Query API limits (500 000 rows,
    # ~100 MB raw / 64 MB compressed, 10-minute timeout) and composes
    # cleanly with the Option A server-side retry-collapse: each
    # chunk's KQL runs the full collapse independently.
    #
    # Named with the EntraId* prefix (distinct from the Az path's
    # -InitialSliceHours) because the LA Query API's 500 000-row
    # ceiling is two orders of magnitude higher than Get-AzActivityLog's
    # 5 000 default, so a shared parameter name would tempt callers
    # into using Az-appropriate values against the LA path where the
    # sensible defaults differ radically.
    # .PARAMETER EntraIdMinSliceMinutes
    # Minimum chunk width in minutes. When a chunk's row count reaches
    # -EntraIdMaxRecordHint and the chunk's current width is at least
    # twice this floor, the chunk is adaptively subdivided at its
    # integer-minute midpoint so neither resulting half drops below
    # the floor. Subdivision stops once the chunk's width is below
    # twice this floor, to guarantee progress. Default is 15.
    # .PARAMETER EntraIdMaxRecordHint
    # Row-count ceiling that triggers adaptive subdivision. When a
    # chunk's query returns at least this many rows, the chunk is
    # subdivided (if its current width is at least twice
    # -EntraIdMinSliceMinutes) rather than emitted, because a value
    # at or near the LA 500 000-row API cap implies the result was
    # likely truncated. Default is 450 000 (approximately 90 % of
    # the API cap, leaving headroom so a chunk approaching the limit
    # is subdivided before the API can truncate the result).
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
    # .EXAMPLE
    # $arrEvents = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId '12345678-1234-1234-1234-123456789012' -Start (Get-Date).AddDays(-30) -End (Get-Date) -EntraIdInitialSliceHours 6 -EntraIdMinSliceMinutes 5 -EntraIdMaxRecordHint 400000)
    # # Narrower initial chunks (6 hours), a lower subdivision floor
    # # (5 minutes), and a lower row-count ceiling (400 000). Useful
    # # for high-volume tenants where the default 24-hour chunks
    # # approach the LA Query API 500 000-row ceiling.
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
    # Version: 1.6.20260422.0

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

        [hashtable]$UnmappedActivityAccumulator,

        [ValidateRange(1, 168)]
        [int]$EntraIdInitialSliceHours = 24,

        [ValidateRange(1, 1440)]
        [int]$EntraIdMinSliceMinutes = 15,

        [ValidateRange(1000, 500000)]
        [int]$EntraIdMaxRecordHint = 450000
    )

    process {
        try {
            $dtStartUtc = $Start.ToUniversalTime()
            $dtEndUtc = $End.ToUniversalTime()

            if ($dtEndUtc -le $dtStartUtc) {
                Write-Verbose ("Querying AuditLogs table in workspace {0}: End ({1:yyyy-MM-ddTHH:mm:ssZ}) is not after Start ({2:yyyy-MM-ddTHH:mm:ssZ}); no events to emit." -f $WorkspaceId, $dtEndUtc, $dtStartUtc)
                return
            }

            Write-Verbose ("Querying AuditLogs table in workspace {0} from {1:yyyy-MM-ddTHH:mm:ssZ} to {2:yyyy-MM-ddTHH:mm:ssZ} in chunks (InitialSliceHours={3}, MinSliceMinutes={4}, MaxRecordHint={5})..." -f $WorkspaceId, $dtStartUtc, $dtEndUtc, $EntraIdInitialSliceHours, $EntraIdMinSliceMinutes, $EntraIdMaxRecordHint)

            # Build the initial chunk list by splitting [Start, End] into
            # consecutive windows of -EntraIdInitialSliceHours each. The
            # final chunk is truncated to End so the total time range is
            # covered exactly once with no gaps or overlaps. Boundary
            # inclusivity is handled by the per-chunk KQL below.
            $listInitialChunks = New-Object System.Collections.Generic.List[pscustomobject]
            $dtCursor = $dtStartUtc
            while ($dtCursor -lt $dtEndUtc) {
                $dtChunkEnd = $dtCursor.AddHours($EntraIdInitialSliceHours)
                if ($dtChunkEnd -gt $dtEndUtc) {
                    $dtChunkEnd = $dtEndUtc
                }
                [void]($listInitialChunks.Add([pscustomobject]@{
                            SegStart = $dtCursor
                            SegEnd = $dtChunkEnd
                        }))
                $dtCursor = $dtChunkEnd
            }

            # Push chunks onto a LIFO stack in reverse order so that
            # pops yield chunks in forward time order. Adaptive
            # subdivision pushes two halves back onto the same stack,
            # second-half first, so the first half is processed before
            # advancing past the midpoint. This preserves time-ordered
            # event emission analogous to Get-AzActivityAdminEvent.
            $stackSegments = New-Object System.Collections.Generic.Stack[pscustomobject]
            for ($i = $listInitialChunks.Count - 1; $i -ge 0; $i--) {
                [void]($stackSegments.Push($listInitialChunks[$i]))
            }

            $intEmitted = 0
            $intSkipped = 0
            $intUnmapped = 0
            $intChunksProcessed = 0
            $intChunksSubdivided = 0

            while ($stackSegments.Count -gt 0) {
                $objSeg = $stackSegments.Pop()
                $dtSegStart = [datetime]$objSeg.SegStart
                $dtSegEnd = [datetime]$objSeg.SegEnd

                # A chunk is "terminal" when its upper boundary equals
                # the overall End of the caller-requested range; only
                # the terminal chunk uses a closed (<=) upper bound so
                # that the overall [Start, End] interval reproduces the
                # pre-chunking `between(...)` semantics. All other
                # chunks use a half-open (<) upper bound so that a row
                # whose TimeGenerated lands exactly on an internal
                # chunk boundary is counted once by the chunk that owns
                # the interval starting at that timestamp.
                $boolTerminalChunk = ($dtSegEnd -eq $dtEndUtc)

                # Build KQL. The chunk boundaries are stamped directly
                # into the query so each chunk sees only its own time
                # slice; the Option A server-side retry-collapse
                # (arg_min over PrincipalKey, OperationName,
                # CorrelationId with the null-CorrelationId union
                # bypass) runs independently per chunk and composes
                # correctly because retry duplicates share a
                # CorrelationId and therefore cannot straddle chunk
                # boundaries in any tenant that issues a single
                # correlation ID per logical operation.
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

                $strSegStartUtc = $dtSegStart.ToString("o")
                $strSegEndUtc = $dtSegEnd.ToString("o")
                if ($boolTerminalChunk) {
                    $strTimeFilter = ("TimeGenerated >= datetime($strSegStartUtc) and TimeGenerated <= datetime($strSegEndUtc)")
                } else {
                    $strTimeFilter = ("TimeGenerated >= datetime($strSegStartUtc) and TimeGenerated < datetime($strSegEndUtc)")
                }

                $strKql = @"
let src =
    AuditLogs
    | where $strTimeFilter
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

                if ($DebugPreference -ne 'SilentlyContinue') {
                    Write-Debug ("KQL query for chunk [{0:yyyy-MM-ddTHH:mm:ssZ} .. {1:yyyy-MM-ddTHH:mm:ssZ}{2}]: {3}" -f $dtSegStart, $dtSegEnd, $(if ($boolTerminalChunk) { ']' } else { ')' }), $strKql)
                }

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

                # Adaptive subdivision: when a chunk's row count
                # reaches or exceeds -EntraIdMaxRecordHint, the chunk
                # likely approached (or hit) the LA Query API 500 000-
                # row ceiling and its contents may be truncated. Split
                # the chunk in half and re-query each half. Stop
                # subdividing once the chunk's span is below twice the
                # -EntraIdMinSliceMinutes floor; splitting further
                # would yield a half below the floor, so we accept the
                # chunk's results as-is to guarantee progress even on
                # pathologically dense time windows.
                $dblSegMinutes = ($dtSegEnd - $dtSegStart).TotalMinutes
                if ($arrRows.Count -ge $EntraIdMaxRecordHint -and $dblSegMinutes -ge (2 * $EntraIdMinSliceMinutes)) {
                    $intChunksSubdivided++
                    # Integer-minute midpoint so a chunk at the floor
                    # cannot spawn a half smaller than 1 minute due to
                    # floating-point remainder.
                    $intHalfMinutes = [int][Math]::Floor($dblSegMinutes / 2.0)
                    if ($intHalfMinutes -lt 1) {
                        $intHalfMinutes = 1
                    }
                    $dtMid = $dtSegStart.AddMinutes($intHalfMinutes)
                    if ($dtMid -le $dtSegStart -or $dtMid -ge $dtSegEnd) {
                        # Degenerate split (shouldn't happen given the
                        # minimum-width guard above, but be defensive):
                        # fall through and accept the chunk's rows.
                        Write-Debug ("Adaptive subdivision produced a degenerate midpoint for chunk [{0:o} .. {1:o}]; accepting {2} rows as-is." -f $dtSegStart, $dtSegEnd, $arrRows.Count)
                    } else {
                        Write-Verbose ("  Chunk [{0:yyyy-MM-ddTHH:mm:ssZ} .. {1:yyyy-MM-ddTHH:mm:ssZ}] returned {2} rows (>= MaxRecordHint {3}); subdividing at {4:yyyy-MM-ddTHH:mm:ssZ}." -f $dtSegStart, $dtSegEnd, $arrRows.Count, $EntraIdMaxRecordHint, $dtMid)
                        # Push second half first so first half pops
                        # first and time order is preserved.
                        [void]($stackSegments.Push([pscustomobject]@{
                                    SegStart = $dtMid
                                    SegEnd = $dtSegEnd
                                }))
                        [void]($stackSegments.Push([pscustomobject]@{
                                    SegStart = $dtSegStart
                                    SegEnd = $dtMid
                                }))
                        continue
                    }
                }

                $intChunksProcessed++
                Write-Verbose ("  Chunk [{0:yyyy-MM-ddTHH:mm:ssZ} .. {1:yyyy-MM-ddTHH:mm:ssZ}]: {2} rows" -f $dtSegStart, $dtSegEnd, $arrRows.Count)

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
            }

            if ($intUnmapped -gt 0) {
                Write-Verbose ("  Unmapped activities: {0}" -f $intUnmapped)
            }
            Write-Verbose ("  Chunks processed: {0}, chunks subdivided: {1}, events emitted: {2}, records skipped: {3}" -f $intChunksProcessed, $intChunksSubdivided, $intEmitted, $intSkipped)
        } catch {
            Write-Debug ("Get-EntraIdAuditEventFromLogAnalytics failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
