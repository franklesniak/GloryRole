Set-StrictMode -Version Latest

function ConvertTo-PrincipalDisplayNameMap {
    # .SYNOPSIS
    # Builds a principal display-name lookup hashtable from canonical
    # admin events.
    # .DESCRIPTION
    # Walks an array of canonical admin event objects and produces a
    # hashtable that maps each event's PrincipalKey (typically a GUID
    # or AppId) to a human-readable display name. The first event seen
    # for a given PrincipalKey wins (subsequent events for the same key
    # are ignored), so the precedence rules are concentrated in one
    # place rather than duplicated per ingestion mode. For each
    # principal:
    #   - If PrincipalUPN is non-empty/non-whitespace, the UPN is used.
    #   - Otherwise, the PrincipalKey itself is used as the display name
    #     (typical for application identities, where no UPN exists).
    # .PARAMETER Events
    # An array of canonical admin event objects. Each object is
    # expected to expose `PrincipalKey` and `PrincipalUPN` properties.
    # An empty array yields an empty hashtable.
    # .EXAMPLE
    # $arrEvents = @(
    #     [pscustomobject]@{ PrincipalKey = '11111111-1111-1111-1111-111111111111'; PrincipalUPN = 'alice@contoso.com' }
    #     [pscustomobject]@{ PrincipalKey = '22222222-2222-2222-2222-222222222222'; PrincipalUPN = $null }
    # )
    # $hashMap = ConvertTo-PrincipalDisplayNameMap -Events $arrEvents
    # # $hashMap['11111111-1111-1111-1111-111111111111'] = 'alice@contoso.com'
    # # $hashMap['22222222-2222-2222-2222-222222222222'] = '22222222-2222-2222-2222-222222222222'
    # .EXAMPLE
    # $arrEvents = @(
    #     [pscustomobject]@{ PrincipalKey = '11111111-1111-1111-1111-111111111111'; PrincipalUPN = 'alice@contoso.com' }
    #     [pscustomobject]@{ PrincipalKey = '11111111-1111-1111-1111-111111111111'; PrincipalUPN = 'alice.alt@contoso.com' }
    # )
    # $hashMap = ConvertTo-PrincipalDisplayNameMap -Events $arrEvents
    # # First-write-wins: the second event for the same PrincipalKey is
    # # ignored, so the original UPN is preserved:
    # # $hashMap['11111111-1111-1111-1111-111111111111'] = 'alice@contoso.com'
    # .EXAMPLE
    # $hashMap = ConvertTo-PrincipalDisplayNameMap -Events @()
    # # $hashMap.Count = 0
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [hashtable] A hashtable keyed by principal key (string) whose
    # values are the resolved display names (string). Returns an empty
    # hashtable when the input array is empty.
    # .NOTES
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
    #   Position 0: Events
    #
    # This is a private (non-exported) module helper used by
    # Invoke-RoleMiningPipeline to consolidate display-name precedence
    # rules across ingestion modes that produce canonical events with
    # PrincipalUPN metadata (e.g., ActivityLog, EntraId).
    #
    # Version: 1.0.20260415.0

    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Events
    )

    process {
        try {
            $hashDisplayNames = @{}

            foreach ($objEvent in $Events) {
                $strKey = [string]$objEvent.PrincipalKey
                if ($hashDisplayNames.ContainsKey($strKey)) {
                    continue
                }

                if (-not [string]::IsNullOrWhiteSpace($objEvent.PrincipalUPN)) {
                    $hashDisplayNames[$strKey] = [string]$objEvent.PrincipalUPN
                } else {
                    $hashDisplayNames[$strKey] = $strKey
                }
            }

            return $hashDisplayNames
        } catch {
            Write-Debug ("ConvertTo-PrincipalDisplayNameMap failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
