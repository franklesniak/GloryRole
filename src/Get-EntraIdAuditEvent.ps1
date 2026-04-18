Set-StrictMode -Version Latest

function Get-EntraIdAuditEvent {
    # .SYNOPSIS
    # Collects canonical admin events from Entra ID directory audit logs
    # via Microsoft Graph API with pagination and transient-failure retry.
    # .DESCRIPTION
    # Retrieves Entra ID directory audit records via
    # Get-MgAuditLogDirectoryAudit from the Microsoft.Graph.Reports
    # module. Supports date range filtering and optional category
    # filtering. Converts each record to a CanonicalEntraIdEvent using
    # ConvertFrom-EntraIdAuditRecord and streams successful events to
    # the pipeline.
    #
    # Pagination is handled automatically by requesting all pages from
    # the Graph API. The function uses -All to retrieve complete results.
    #
    # **Transient-failure resilience (retry/backoff).**
    # The Microsoft.Graph PowerShell SDK (v2.x, Kiota-based) includes
    # built-in HTTP-level retry for 429/503/504 responses (default: 3
    # retries with exponential backoff, respecting Retry-After headers).
    # This function adds a complementary function-level retry loop
    # around the entire cmdlet invocation to handle failures that the
    # SDK cannot recover from internally:
    # - Network-layer failures (DNS, TCP, TLS)
    # - SDK-exhausted throttle errors (429 after SDK internal retries)
    # - Transient server errors persisting beyond SDK retry budget
    # The outer retry uses exponential backoff with random jitter to
    # avoid synchronized retry storms. Retry count and base delay are
    # configurable via -MaxRetries and -RetryBaseDelaySeconds. Retry
    # progress is visible via Write-Verbose and Write-Debug.
    #
    # **Exception classification.** The retry loop distinguishes
    # transient from permanent failures on two axes. First,
    # PowerShell-level permanent exceptions
    # (System.Management.Automation.CommandNotFoundException,
    # System.Management.Automation.ParameterBindingException) bypass
    # the retry loop immediately -- these indicate local configuration
    # problems (missing Microsoft.Graph.Reports module, bad parameter
    # input) that retrying cannot fix. Second, when an HTTP status
    # code is recoverable from the thrown exception, non-retriable
    # 4xx codes (400 Bad Request, 401 Unauthorized, 403 Forbidden,
    # 404 Not Found, etc.) also bypass the retry loop so permanent
    # remote failures surface without backoff delay. 408 (Request
    # Timeout) and 429 (Too Many Requests) remain retriable alongside
    # all 5xx status codes, network-layer errors that do not expose
    # an HTTP status, and any exception whose status code cannot be
    # extracted (which falls through to the retry path as a safe
    # default).
    #
    # **Time-window subdivision: not required.**
    # Unlike Azure Activity Log (which has a MaxRecord cap that can
    # silently truncate results and benefits from adaptive time-slicing
    # in Get-AzActivityAdminEvent), the Microsoft Graph directoryAudits
    # endpoint uses server-side OData pagination via -All. The SDK
    # transparently follows @odata.nextLink tokens until all pages are
    # retrieved, so there is no truncation risk and no benefit to
    # subdividing the query time window at the GloryRole level.
    #
    # Two distinct failure modes apply to individual records:
    # - **Intentional skips.** Records that do not meet the
    #   canonicalization criteria (e.g., non-success result, missing
    #   principal, unmapped activity) cause
    #   ConvertFrom-EntraIdAuditRecord to return $null. These records
    #   are silently skipped and counted in the verbose "Records
    #   skipped" tally. This behavior is NOT controlled by
    #   -ErrorAction; skips are the normal non-error path.
    # - **Exceptions.** Two distinct propagation paths apply:
    #   - Terminating errors from the Microsoft Graph call
    #     (e.g., connection failures, authorization failures, or
    #     throttling that persists beyond the SDK's internal retry
    #     budget) are retried per -MaxRetries and propagate to the
    #     caller only after retry exhaustion.
    #   - Terminating errors from ConvertFrom-EntraIdAuditRecord
    #     (invoked after the Graph call succeeds) are not retried
    #     and propagate to the caller immediately.
    #   Both paths propagate regardless of -ErrorAction setting.
    # .PARAMETER Start
    # The start of the time range to query.
    # .PARAMETER End
    # The end of the time range to query.
    # .PARAMETER FilterCategory
    # Optional. One or more audit log categories to filter by (e.g.,
    # 'GroupManagement', 'UserManagement', 'RoleManagement'). When
    # specified, only records matching these categories are retrieved.
    # When omitted, all categories are returned.
    # .PARAMETER UnmappedActivityAccumulator
    # Optional. A [hashtable] reference that, when provided, receives
    # entries for each unmapped Entra ID activity encountered during
    # ingestion. Keys are "ActivityDisplayName|Category" composite
    # strings. Values are PSCustomObjects with ActivityDisplayName,
    # Category, Count, SampleCorrelationId, and SampleRecordId
    # properties. The caller creates the hashtable and passes it in;
    # this function populates it as a side effect. When omitted,
    # unmapped activities are silently skipped as before.
    # .PARAMETER MaxRetries
    # Optional. Maximum number of retry attempts for transient Graph
    # API failures. Default is 3. Set to 0 to disable retries. Each
    # retry uses exponential backoff with jitter. The total number of
    # Graph API call attempts is MaxRetries + 1 (one initial attempt
    # plus up to MaxRetries retries).
    # .PARAMETER RetryBaseDelaySeconds
    # Optional. Base delay in seconds for exponential backoff between
    # retries. Default is 2. The actual delay for retry N (0-based) is
    # (2^N * RetryBaseDelaySeconds) + jitter, where jitter is a random
    # value in the half-open interval [0 s, 1 s) (0 inclusive, 1
    # exclusive). For example, with default settings: ~2s, ~4s, ~8s
    # for retries 1-3.
    # .EXAMPLE
    # $arrEvents = @(Get-EntraIdAuditEvent -Start (Get-Date).AddDays(-30) -End (Get-Date))
    # # Retrieves all successful Entra ID admin events for the last
    # # 30 days and wraps the call in @() to guarantee an array result.
    # .EXAMPLE
    # $arrEvents = @(Get-EntraIdAuditEvent -Start (Get-Date).AddDays(-7) -End (Get-Date) -FilterCategory @('GroupManagement', 'UserManagement'))
    # # Retrieves only GroupManagement and UserManagement events from
    # # the last 7 days.
    # .EXAMPLE
    # $hashUnmapped = @{}
    # $arrEvents = @(Get-EntraIdAuditEvent -Start (Get-Date).AddDays(-30) -End (Get-Date) -UnmappedActivityAccumulator $hashUnmapped)
    # # $hashUnmapped now contains entries for each unmapped activity
    # # with Count, Category, and sample IDs for diagnostics.
    # .EXAMPLE
    # $arrEvents = @(Get-EntraIdAuditEvent -Start (Get-Date).AddDays(-30) -End (Get-Date) -MaxRetries 5 -RetryBaseDelaySeconds 3)
    # # Retrieves events with up to 5 retries on transient Graph API
    # # failures, using 3 seconds as the base delay for exponential
    # # backoff. Actual delays: ~3s, ~6s, ~12s, ~24s, ~48s plus jitter.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] CanonicalEntraIdEvent objects streamed to the
    # pipeline.
    # .NOTES
    # Requires the Microsoft.Graph.Reports module and an active
    # Microsoft Graph connection (Connect-MgGraph with AuditLog.Read.All
    # permission).
    # Requires ConvertFrom-EntraIdAuditRecord and
    # ConvertTo-EntraIdResourceAction to be loaded.
    #
    # Microsoft.Graph SDK retry characterization (v2.x, Kiota-based):
    # The SDK's Kiota HTTP handler retries on HTTP 429, 503, and 504
    # responses. Default retry limit: 3 attempts. It respects
    # Retry-After headers and uses exponential backoff between
    # attempts. Retries are transparent to the caller; the SDK
    # surfaces the final error only after exhausting its internal
    # budget. This function's retry loop operates at the cmdlet
    # invocation level, complementing (not replacing) the SDK's
    # HTTP-level retry.
    #
    # Time-window subdivision rationale:
    # The Graph directoryAudits endpoint paginates via
    # @odata.nextLink (fetched automatically by -All). Unlike
    # Get-AzActivityLog (which has a MaxRecord cap that can silently
    # truncate results), Graph pagination guarantees complete result
    # sets. Adaptive time-slicing would not improve completeness and
    # was therefore deliberately omitted for Entra ID ingestion.
    #
    # Supported on Windows PowerShell 5.1 (.NET Framework 4.6.2+) and
    # PowerShell 7.4.x / 7.5.x / 7.6.x (Windows, macOS, Linux).
    #
    # This function supports positional parameters:
    #   Position 0: Start
    #   Position 1: End
    #
    # Version: 1.4.20260418.7

    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [datetime]$Start,

        [Parameter(Mandatory = $true, Position = 1)]
        [datetime]$End,

        [string[]]$FilterCategory,

        [hashtable]$UnmappedActivityAccumulator,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$MaxRetries = 3,

        [ValidateRange(0, [double]::MaxValue)]
        [double]$RetryBaseDelaySeconds = 2
    )

    process {
        try {
            Write-Verbose ("Querying Entra ID audit logs from {0:yyyy-MM-ddTHH:mm:ssZ} to {1:yyyy-MM-ddTHH:mm:ssZ}..." -f $Start.ToUniversalTime(), $End.ToUniversalTime())

            # Build the OData filter for date range and success result
            $strStartUtc = $Start.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            $strEndUtc = $End.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

            $strFilter = ("activityDateTime ge {0} and activityDateTime le {1} and result eq 'success'" -f $strStartUtc, $strEndUtc)

            # Add category filter if specified. Category values are
            # embedded as OData string literals, which delimit strings
            # with single quotes and escape a literal single quote by
            # doubling it (e.g., O'Brien -> 'O''Brien'). Skip null or
            # whitespace-only entries so they don't create invalid
            # `category eq ''` clauses.
            if ($null -ne $FilterCategory -and $FilterCategory.Count -gt 0) {
                $arrCategoryFilters = @()
                foreach ($strCat in $FilterCategory) {
                    if ([string]::IsNullOrWhiteSpace($strCat)) {
                        continue
                    }
                    $strEscapedCat = $strCat.Replace("'", "''")
                    $arrCategoryFilters += ("category eq '{0}'" -f $strEscapedCat)
                }
                if ($arrCategoryFilters.Count -gt 0) {
                    $strCategoryFilter = $arrCategoryFilters -join ' or '
                    $strFilter = ("{0} and ({1})" -f $strFilter, $strCategoryFilter)
                }
            }

            Write-Debug ("OData filter: {0}" -f $strFilter)

            $hashParams = @{
                Filter = $strFilter
                All = $true
                ErrorAction = 'Stop'
            }

            # Suppress verbose output from Microsoft.Graph module which
            # can be extremely noisy during pagination. The retry loop
            # wraps the cmdlet call with exponential backoff + jitter
            # for transient failures that survive the SDK's internal
            # HTTP-level retry (see .NOTES for SDK characterization).
            $objVerbosePreferenceAtStartOfBlock = $VerbosePreference
            $arrRaw = $null
            $intAttempt = 0
            $boolSucceeded = $false
            while (-not $boolSucceeded) {
                $intAttempt++
                try {
                    $VerbosePreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
                    $arrRaw = @(Get-MgAuditLogDirectoryAudit @hashParams)
                    $VerbosePreference = $objVerbosePreferenceAtStartOfBlock
                    $boolSucceeded = $true
                    if ($intAttempt -gt 1) {
                        Write-Verbose ("  Graph API call succeeded on attempt {0}" -f $intAttempt)
                    }
                } catch {
                    $VerbosePreference = $objVerbosePreferenceAtStartOfBlock
                    # Classify: rethrow PowerShell-level permanent
                    # exceptions immediately. These arise from local
                    # configuration problems (a missing module, a
                    # parameter-binding error) rather than transient
                    # Graph API conditions, so retrying them only
                    # delays the real error and does not improve
                    # outcomes. Checked before the HTTP-status
                    # extraction below because these exception types
                    # do not carry a Response.StatusCode.
                    if ($_.Exception -is [System.Management.Automation.CommandNotFoundException] -or
                        $_.Exception -is [System.Management.Automation.ParameterBindingException]) {
                        Write-Debug ("Graph API call failed with permanent PowerShell exception {0}: {1}" -f $_.Exception.GetType().FullName, $_.Exception.Message)
                        Write-Verbose ("  Graph API call failed with permanent PowerShell error ({0}). Not retrying." -f $_.Exception.GetType().Name)
                        throw
                    }
                    # Classify: rethrow non-retriable HTTP 4xx status
                    # codes immediately. 400 Bad Request, 401
                    # Unauthorized, 403 Forbidden, 404 Not Found, and
                    # similar codes indicate permanent failures that
                    # will not resolve on retry; backing off only
                    # delays the error and obscures the real cause.
                    # The Microsoft.Graph SDK (Kiota-based v2.x)
                    # exposes HTTP status via the exception's
                    # Response.StatusCode chain when available; under
                    # strict mode the property access throws when the
                    # member is absent, so wrap the lookup in
                    # try/catch and treat any failure-to-extract as
                    # "unclassifiable, keep retrying" -- preserving
                    # the previous retry-everything behavior as a
                    # safe fallback. 408 Request Timeout and 429 Too
                    # Many Requests remain retriable alongside all
                    # 5xx codes and network-layer errors.
                    $intHttpStatus = 0
                    try {
                        $intHttpStatus = [int]($_.Exception.Response.StatusCode)
                    } catch {
                        $intHttpStatus = 0
                    }
                    if ($intHttpStatus -ge 400 -and $intHttpStatus -lt 500 -and
                        $intHttpStatus -ne 408 -and $intHttpStatus -ne 429) {
                        Write-Debug ("Graph API non-retriable HTTP {0}: {1}" -f $intHttpStatus, $_.Exception.Message)
                        Write-Verbose ("  Graph API call failed with non-retriable HTTP {0}. Not retrying." -f $intHttpStatus)
                        throw
                    }
                    $intRetryNumber = $intAttempt - 1
                    if ($intRetryNumber -ge $MaxRetries) {
                        Write-Debug ("Graph API retry exhausted after {0} retries: {1}" -f $MaxRetries, $_.Exception.Message)
                        Write-Verbose ("  Graph API call failed after {0} retries. Giving up." -f $MaxRetries)
                        throw
                    }
                    $dblBackoff = [math]::Pow(2, $intRetryNumber) * $RetryBaseDelaySeconds
                    $dblJitter = (Get-Random -Minimum 0 -Maximum 1000) / 1000.0
                    $dblDelay = $dblBackoff + $dblJitter
                    $intTotalAttempts = $MaxRetries + 1
                    # Guard against a non-finite computed delay before
                    # any diagnostics or sleep. [math]::Pow(2, N) can
                    # overflow to [double]::PositiveInfinity for very
                    # large N, and the subsequent multiplication and
                    # addition would also yield Infinity (or NaN). A
                    # chunked sleep over Infinity would never
                    # terminate; fail fast with a clear error.
                    if ([double]::IsInfinity($dblDelay) -or [double]::IsNaN($dblDelay)) {
                        Write-Debug ("Retry aborted: non-finite backoff ({0} s). Last error: {1}" -f $dblDelay, $_.Exception.Message)
                        throw ("Retry backoff computed a non-finite delay ({0} s) from -MaxRetries={1}, -RetryBaseDelaySeconds={2}. Reduce these parameters so 2^N * base + jitter stays finite." -f $dblDelay, $MaxRetries, $RetryBaseDelaySeconds)
                    }
                    Write-Verbose ("  Graph API call failed (attempt {0}/{1}): {2}. Retrying in {3:F1}s..." -f $intAttempt, $intTotalAttempts, $_.Exception.Message, $dblDelay)
                    Write-Debug ("  Retry backoff: base={0:F1}s, jitter={1:F3}s, total={2:F1}s" -f $dblBackoff, $dblJitter, $dblDelay)
                    # Sleep in chunks bounded by [int]::MaxValue
                    # milliseconds. Extreme configurations (e.g., a
                    # large MaxRetries combined with a large base
                    # delay) can produce a delay in milliseconds that
                    # exceeds the [int] range accepted by Start-Sleep
                    # -Milliseconds; casting directly would overflow
                    # and surface a confusing error from inside the
                    # retry handler.
                    $intMaxSleepMilliseconds = [int]::MaxValue
                    $dblRemainingSleepMilliseconds = $dblDelay * 1000.0
                    while ($dblRemainingSleepMilliseconds -ge 1) {
                        $intSleepChunkMilliseconds = [int][math]::Min($dblRemainingSleepMilliseconds, [double]$intMaxSleepMilliseconds)
                        Start-Sleep -Milliseconds $intSleepChunkMilliseconds
                        $dblRemainingSleepMilliseconds -= $intSleepChunkMilliseconds
                    }
                } finally {
                    $VerbosePreference = $objVerbosePreferenceAtStartOfBlock
                }
            }

            Write-Verbose ("  Raw audit records retrieved: {0}" -f $arrRaw.Count)

            # Delegate accumulator tracking to ConvertFrom-EntraIdAuditRecord
            # so the record's eligibility (success, principal, valid
            # date) is verified in a single place before the mapping
            # check. This prevents records dropped for reasons other
            # than missing mapping (non-success, no InitiatedBy,
            # unparseable ActivityDateTime) from being miscounted as
            # unmapped activities.
            $hashConvertParams = @{
                Record = $null
            }
            if ($null -ne $UnmappedActivityAccumulator) {
                $hashConvertParams['UnmappedActivityAccumulator'] = $UnmappedActivityAccumulator
            }

            $intEmitted = 0
            $intSkipped = 0
            foreach ($objRecord in $arrRaw) {
                $hashConvertParams['Record'] = $objRecord
                $objEvent = ConvertFrom-EntraIdAuditRecord @hashConvertParams
                if ($null -eq $objEvent) {
                    $intSkipped++
                    continue
                }
                $intEmitted++
                $objEvent
            }

            if ($null -ne $UnmappedActivityAccumulator -and $UnmappedActivityAccumulator.Count -gt 0) {
                $intUnmappedDistinct = $UnmappedActivityAccumulator.Count
                $intUnmappedTotal = 0
                foreach ($objEntry in $UnmappedActivityAccumulator.Values) {
                    $intUnmappedTotal += $objEntry.Count
                }
                Write-Verbose ("  Unmapped activities: {0} occurrences across {1} distinct names" -f $intUnmappedTotal, $intUnmappedDistinct)
            }
            Write-Verbose ("  Events emitted: {0}, Records skipped: {1}" -f $intEmitted, $intSkipped)
        } catch {
            Write-Debug ("Get-EntraIdAuditEvent failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
