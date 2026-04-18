Set-StrictMode -Version Latest

function Get-EntraIdAuditEvent {
    # .SYNOPSIS
    # Collects canonical admin events from Entra ID directory audit logs
    # via Microsoft Graph API with pagination.
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
    # Two distinct failure modes apply to individual records:
    # - **Intentional skips.** Records that do not meet the
    #   canonicalization criteria (e.g., non-success result, missing
    #   principal, unmapped activity) cause
    #   ConvertFrom-EntraIdAuditRecord to return $null. These records
    #   are silently skipped and counted in the verbose "Records
    #   skipped" tally. This behavior is NOT controlled by
    #   -ErrorAction; skips are the normal non-error path.
    # - **Exceptions.** Terminating errors from Microsoft Graph
    #   (e.g., connection failures, authorization failures) or from
    #   ConvertFrom-EntraIdAuditRecord are always propagated to the
    #   caller, regardless of -ErrorAction setting.
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
    # Supported on Windows PowerShell 5.1 (.NET Framework 4.6.2+) and
    # PowerShell 7.4.x / 7.5.x / 7.6.x (Windows, macOS, Linux).
    #
    # This function supports positional parameters:
    #   Position 0: Start
    #   Position 1: End
    #
    # Version: 1.1.20260418.0

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [datetime]$Start,

        [Parameter(Mandatory = $true)]
        [datetime]$End,

        [string[]]$FilterCategory,

        [hashtable]$UnmappedActivityAccumulator
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
            # can be extremely noisy during pagination.
            $objVerbosePreferenceAtStartOfBlock = $VerbosePreference
            $arrRaw = $null
            try {
                $VerbosePreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
                $arrRaw = @(Get-MgAuditLogDirectoryAudit @hashParams)
                $VerbosePreference = $objVerbosePreferenceAtStartOfBlock
            } catch {
                Write-Debug ("Get-MgAuditLogDirectoryAudit query failed: {0}" -f $_.Exception.Message)
                throw
            } finally {
                $VerbosePreference = $objVerbosePreferenceAtStartOfBlock
            }

            Write-Verbose ("  Raw audit records retrieved: {0}" -f $arrRaw.Count)

            $intEmitted = 0
            $intSkipped = 0
            $intUnmapped = 0
            foreach ($objRecord in $arrRaw) {
                $objEvent = ConvertFrom-EntraIdAuditRecord -Record $objRecord
                if ($null -eq $objEvent) {
                    $intSkipped++

                    # Track unmapped activities when an accumulator is
                    # provided. A record is an "unmapped activity" when
                    # it passed the success and principal checks but the
                    # mapping returned $null. Check: result is success,
                    # ActivityDisplayName is present, then call
                    # ConvertTo-EntraIdResourceAction (cheap hashtable
                    # lookup because the mapping table is cached).
                    if ($null -ne $UnmappedActivityAccumulator -and
                        $null -ne $objRecord.Result -and
                        [string]$objRecord.Result -eq 'success' -and
                        $null -ne $objRecord.ActivityDisplayName -and
                        -not [string]::IsNullOrWhiteSpace([string]$objRecord.ActivityDisplayName)) {

                        $strTestAction = ConvertTo-EntraIdResourceAction -ActivityDisplayName ([string]$objRecord.ActivityDisplayName) -Category ([string]$objRecord.Category)
                        if ($null -eq $strTestAction) {
                            $intUnmapped++
                            $strAccKey = ("{0}|{1}" -f ([string]$objRecord.ActivityDisplayName).Trim(), [string]$objRecord.Category)
                            if ($UnmappedActivityAccumulator.ContainsKey($strAccKey)) {
                                $UnmappedActivityAccumulator[$strAccKey].Count++
                            } else {
                                $strSampleCorrelation = ''
                                if ($null -ne $objRecord.CorrelationId) {
                                    $strSampleCorrelation = [string]$objRecord.CorrelationId
                                }
                                $strSampleRecordId = ''
                                if ($null -ne $objRecord.Id) {
                                    $strSampleRecordId = [string]$objRecord.Id
                                }
                                $UnmappedActivityAccumulator[$strAccKey] = [pscustomobject]@{
                                    ActivityDisplayName = ([string]$objRecord.ActivityDisplayName).Trim()
                                    Category = [string]$objRecord.Category
                                    Count = 1
                                    SampleCorrelationId = $strSampleCorrelation
                                    SampleRecordId = $strSampleRecordId
                                }
                            }
                        }
                    }

                    continue
                }
                $intEmitted++
                $objEvent
            }

            if ($intUnmapped -gt 0) {
                Write-Verbose ("  Unmapped activities: {0}" -f $intUnmapped)
            }
            Write-Verbose ("  Events emitted: {0}, Records skipped: {1}" -f $intEmitted, $intSkipped)
        } catch {
            Write-Debug ("Get-EntraIdAuditEvent failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
