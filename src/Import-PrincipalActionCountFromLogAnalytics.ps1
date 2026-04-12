Set-StrictMode -Version Latest

function Import-PrincipalActionCountFromLogAnalytics {
    # .SYNOPSIS
    # Imports pre-aggregated principal-action counts from a Log Analytics
    # workspace using KQL.
    # .DESCRIPTION
    # Queries a Log Analytics workspace for Azure Activity Log data within
    # the specified time range, filtering to succeeded Administrative events
    # and summarizing by PrincipalKey and Action. Returns
    # PrincipalActionCount sparse triples.
    # .PARAMETER WorkspaceId
    # The Log Analytics workspace ID to query.
    # .PARAMETER Start
    # The start of the time range.
    # .PARAMETER End
    # The end of the time range.
    # .EXAMPLE
    # $arrCounts = @(Import-PrincipalActionCountFromLogAnalytics -WorkspaceId 'ws-123' -Start (Get-Date).AddDays(-90) -End (Get-Date))
    # .EXAMPLE
    # $dateStart = [datetime]'2026-01-01'
    # $dateEnd = [datetime]'2026-03-20'
    # $arrCounts = @(Import-PrincipalActionCountFromLogAnalytics -WorkspaceId '12345678-abcd-1234-abcd-1234567890ab' -Start $dateStart -End $dateEnd)
    # # Returns an array of PrincipalActionCount sparse triples with
    # # PrincipalKey, Action, and Count fields.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] PrincipalActionCount sparse triples.
    # .NOTES
    # Requires Az.OperationalInsights module.
    # Requires ConvertTo-NormalizedAction to be loaded.
    #
    # Supported PowerShell versions:
    #   - Windows PowerShell 5.1 (.NET Framework 4.6.2+)
    #   - PowerShell 7.4.x
    #   - PowerShell 7.5.x
    #   - PowerShell 7.6.x
    # Supported operating systems:
    #   - Windows (all supported PowerShell versions)
    #   - macOS (PowerShell 7.x only)
    #   - Linux (PowerShell 7.x only)
    #
    # This function supports positional parameters:
    #   Position 0: WorkspaceId
    #   Position 1: Start
    #   Position 2: End
    #
    # Version: 1.1.20260412.0

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,

        [Parameter(Mandatory = $true)]
        [datetime]$Start,

        [Parameter(Mandatory = $true)]
        [datetime]$End
    )

    process {
        $strKql = @"
AzureActivity
| where TimeGenerated between (datetime($($Start.ToString("o"))) .. datetime($($End.ToString("o"))))
| where CategoryValue == "Administrative"
| where ActivityStatusValue == "Succeeded"
| extend Auth = parse_json(Authorization)
| extend ActionRaw = tostring(Auth.action)
| extend ClaimsObj = parse_json(Claims)
| extend Oid   = tostring(ClaimsObj["http://schemas.microsoft.com/identity/claims/objectidentifier"])
| extend AppId = tostring(ClaimsObj["appid"])
| extend PrincipalKey = case(
    isnotempty(Oid), Oid,
    isnotempty(AppId), AppId,
    isnotempty(Caller), Caller,
    "UNKNOWN"
)
| where PrincipalKey != "UNKNOWN" and isnotempty(ActionRaw)
| extend Action = tolower(trim(" ", ActionRaw))
| summarize Count=count() by PrincipalKey, Action
"@

        Write-Verbose "Querying Log Analytics workspace..."

        $objVerbosePreferenceAtStartOfBlock = $VerbosePreference
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

        $arrRows = $objQueryResult.Results
        Write-Debug ("Received {0} rows from query." -f @($arrRows).Count)

        foreach ($objRow in $arrRows) {
            $strAction = ConvertTo-NormalizedAction -Action ([string]$objRow.Action)
            if ([string]::IsNullOrWhiteSpace($strAction)) {
                Write-Debug "Skipping row: action is empty or whitespace after normalization."
                continue
            }

            [pscustomobject]@{
                PrincipalKey = [string]$objRow.PrincipalKey
                Action = $strAction
                Count = [double]$objRow.Count
            }
        }
    }
}
