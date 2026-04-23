Set-StrictMode -Version Latest

function ConvertTo-PrincipalActionCount {
    # .SYNOPSIS
    # Aggregates canonical admin events into principal-action count sparse
    # triples.
    # .DESCRIPTION
    # Groups canonical admin events by PrincipalKey and Action, summing
    # occurrences to produce PrincipalActionCount sparse triples suitable
    # for downstream vectorization and clustering.
    # .PARAMETER Events
    # An array of CanonicalAdminEvent objects to aggregate.
    # .EXAMPLE
    # $arrEvents = @(
    #     [pscustomobject]@{ PrincipalKey = 'user@example.com'; Action = 'read' }
    #     [pscustomobject]@{ PrincipalKey = 'admin@example.com'; Action = 'write' }
    # )
    # $arrCounts = @(ConvertTo-PrincipalActionCount -Events $arrEvents)
    # # Each unique principal-action pair produces one triple with a count
    # # of 1.0:
    # # $arrCounts[0].PrincipalKey = 'user@example.com'
    # # $arrCounts[0].Action = 'read'
    # # $arrCounts[0].Count = 1.0
    # # $arrCounts[1].PrincipalKey = 'admin@example.com'
    # # $arrCounts[1].Action = 'write'
    # # $arrCounts[1].Count = 1.0
    # .EXAMPLE
    # $arrEvents = @(
    #     [pscustomobject]@{ PrincipalKey = 'user@example.com'; Action = 'read' }
    #     [pscustomobject]@{ PrincipalKey = 'user@example.com'; Action = 'read' }
    #     [pscustomobject]@{ PrincipalKey = 'user@example.com'; Action = 'write' }
    # )
    # $arrCounts = @(ConvertTo-PrincipalActionCount -Events $arrEvents)
    # # Duplicate principal-action pairs are aggregated by summing their
    # # counts. The "read" triple has Count = 2.0 and the "write" triple
    # # has Count = 1.0:
    # # ($arrCounts | Where-Object { $_.Action -eq 'read' }).Count = 2.0
    # # ($arrCounts | Where-Object { $_.Action -eq 'write' }).Count = 1.0
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject]
    # Each output object represents a principal-action count triple with
    # the following properties:
    #   - PrincipalKey ([string]) - the identity key of the principal
    #   - Action ([string]) - the Azure action name
    #   - Count ([double]) - the number of times this principal performed
    #     this action
    # If all input events are malformed or the input array is empty, no
    # objects are emitted to the pipeline.
    # .NOTES
    # Version: 1.2.20260422.0
    # Supported PowerShell versions:
    #   - Windows PowerShell 5.1 (.NET Framework 4.6.2+)
    #   - PowerShell 7.4.x
    #   - PowerShell 7.5.x
    #   - PowerShell 7.6.x
    # Supported operating systems:
    #   - Windows (all supported PowerShell versions)
    #   - macOS (PowerShell 7.x only)
    #   - Linux (PowerShell 7.x only)
    # This function supports positional parameters:
    #   Position 0: Events

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Events
    )

    process {
        try {
            if ($Events.Count -eq 0) {
                Write-Warning "No events provided to aggregate. Output will be empty."
            }

            Write-Verbose ("Aggregating {0} events into principal-action counts..." -f $Events.Count)

            $hashtableCounts = @{}

            #region Aggregation
            foreach ($objEvent in $Events) {
                if ([string]::IsNullOrEmpty($objEvent.PrincipalKey) -or [string]::IsNullOrEmpty($objEvent.Action)) {
                    Write-Warning "Skipping event with missing PrincipalKey or Action property."
                    Write-Debug "Malformed event skipped: missing PrincipalKey or Action."
                    continue
                }

                # Use a pipe-delimited composite key to combine principal
                # identity and action name into a single hash key, enabling
                # O(1) lookup for count aggregation. The pipe character is
                # chosen because it does not appear in Azure resource
                # provider action names.
                $strKey = [string]$objEvent.PrincipalKey + '|' + [string]$objEvent.Action
                if ($hashtableCounts.ContainsKey($strKey)) {
                    $hashtableCounts[$strKey] += 1.0
                } else {
                    # Store counts as [double] from the start because
                    # downstream vectorization and TF-IDF calculations
                    # require floating-point arithmetic; this avoids
                    # type-conversion overhead later.
                    $hashtableCounts[$strKey] = 1.0
                }
            }
            #endregion Aggregation

            Write-Debug ("Aggregation complete: {0} unique principal-action pairs." -f $hashtableCounts.Count)

            #region Output
            foreach ($strKey in $hashtableCounts.Keys) {
                $arrParts = $strKey.Split('|', 2)
                [pscustomobject]@{
                    PrincipalKey = $arrParts[0]
                    Action = $arrParts[1]
                    Count = [double]$hashtableCounts[$strKey]
                }
            }
            #endregion Output

            Write-Verbose ("Emitted {0} principal-action count triples." -f $hashtableCounts.Count)
        } catch {
            Write-Debug ("Failed to aggregate events: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
