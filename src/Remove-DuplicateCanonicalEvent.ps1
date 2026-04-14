Set-StrictMode -Version Latest

function Remove-DuplicateCanonicalEvent {
    # .SYNOPSIS
    # Deduplicates canonical admin events by correlation ID without
    # dropping distinct actions.
    # .DESCRIPTION
    # Removes retry duplicates from canonical events using a composite
    # key built from PrincipalKey, Action, CorrelationId, and (when
    # present) ResourceId. This supports both CanonicalAdminEvent
    # objects (which carry ResourceId) and CanonicalEntraIdEvent objects
    # (which do not). Events without a CorrelationId are always kept.
    # Events are sorted by TimeGenerated before deduplication so the
    # earliest occurrence is retained.
    # .PARAMETER Events
    # An array of canonical event objects to deduplicate. Accepts both
    # CanonicalAdminEvent objects (with ResourceId) and
    # CanonicalEntraIdEvent objects (without ResourceId). When
    # ResourceId is missing from an event, it is treated as an empty
    # string in the composite dedupe key.
    # .EXAMPLE
    # $arrUnique = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)
    # .EXAMPLE
    # $arrEvents = @(
    #     [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = 'abc'; TimeGenerated = (Get-Date) }
    #     [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = 'abc'; TimeGenerated = (Get-Date).AddSeconds(1) }
    # )
    # $arrUnique = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)
    # # $arrUnique.Count is 1 because both events share the same composite key.
    # .EXAMPLE
    # $objNoCorrelation = [pscustomobject]@{ PrincipalKey = 'user2'; Action = 'write'; ResourceId = '/sub/rg'; CorrelationId = $null; TimeGenerated = (Get-Date) }
    # $arrResult = @(Remove-DuplicateCanonicalEvent -Events @($objNoCorrelation, $objNoCorrelation))
    # # $arrResult.Count is 2 because events without a CorrelationId are always kept.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] Deduplicated canonical event objects streamed to
    # the pipeline. Each output object retains all original properties.
    # Supports both CanonicalAdminEvent (with ResourceId) and
    # CanonicalEntraIdEvent (without ResourceId). The earliest event per
    # composite key is retained. Events without a CorrelationId (null,
    # empty, or whitespace-only) are always emitted.
    # .NOTES
    # Supported platforms:
    #   Windows PowerShell 5.1 (.NET Framework 4.6.2+)
    #   PowerShell 7.4.x, 7.5.x, and 7.6.x (Windows, macOS, Linux)
    #
    # This function supports positional parameters:
    #   Position 0: Events
    #
    # Version: 1.2.20260414.1

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'The "Remove-" verb filters an in-memory event collection and streams the deduplicated objects to the pipeline; it does not mutate any external or system state that would warrant ShouldProcess support.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Events
    )

    process {
        Write-Verbose ("Deduplicating {0} canonical event(s)." -f $Events.Count)
        try {
            $hashSeen = @{}

            foreach ($objEvent in ($Events | Sort-Object TimeGenerated)) {
                $strCorrelationId = [string]$objEvent.CorrelationId
                if ([string]::IsNullOrWhiteSpace($strCorrelationId)) {
                    $objEvent
                    continue
                }

                $strResourceId = ''
                if ($null -ne $objEvent.PSObject.Properties['ResourceId'] -and
                    $null -ne $objEvent.ResourceId) {
                    $strResourceId = [string]$objEvent.ResourceId
                }

                $strKey = [string]$objEvent.PrincipalKey + '|' + [string]$objEvent.Action + '|' + $strResourceId + '|' + $strCorrelationId
                Write-Debug ("Composite key constructed for deduplication check.")
                if (-not $hashSeen.ContainsKey($strKey)) {
                    $hashSeen[$strKey] = $true
                    $objEvent
                }
            }
            Write-Debug ("Deduplication complete. Unique keys tracked: {0}." -f $hashSeen.Count)
        } catch {
            Write-Debug ("Remove-DuplicateCanonicalEvent failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
