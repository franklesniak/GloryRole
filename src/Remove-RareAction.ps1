Set-StrictMode -Version Latest

function Remove-RareAction {
    # .SYNOPSIS
    # Prunes rare actions from principal-action counts using dual
    # thresholds.
    # .DESCRIPTION
    # Removes actions that do not meet both the minimum distinct principals
    # threshold and the minimum total count threshold. Returns an object
    # containing the kept counts, dropped counts, and action statistics.
    # .PARAMETER Counts
    # An array of PrincipalActionCount sparse triples. Each element must
    # have the following properties:
    #   - PrincipalKey ([string]): The identity of the principal.
    #   - Action ([string]): The action performed by the principal.
    #   - Count ([double]): The occurrence count for the principal-action
    #     pair.
    # .PARAMETER MinDistinctPrincipals
    # Minimum number of distinct principals an action must have to be
    # kept. Default is 2.
    # .PARAMETER MinTotalCount
    # Minimum total occurrence count an action must have to be kept.
    # Default is 10.
    # .EXAMPLE
    # $objResult = Remove-RareAction -Counts $arrCounts -MinDistinctPrincipals 2 -MinTotalCount 10
    # # $objResult.Kept contains the surviving sparse triples
    # # $objResult.Dropped contains the pruned sparse triples
    # # $objResult.Stats contains per-action statistics
    # .EXAMPLE
    # $arrCounts = @(
    #     [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; Count = 8.0 }
    #     [pscustomobject]@{ PrincipalKey = 'user2'; Action = 'read'; Count = 5.0 }
    #     [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'delete'; Count = 1.0 }
    # )
    # $objResult = Remove-RareAction -Counts $arrCounts
    # # Uses default thresholds: MinDistinctPrincipals=2, MinTotalCount=10.
    # # 'read' has 2 distinct principals and total count 13, so it is kept.
    # # 'delete' has only 1 distinct principal, so it is dropped.
    # # $objResult.Kept contains the two 'read' triples.
    # # $objResult.Dropped contains the one 'delete' triple.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] An object with the following properties:
    #   - Kept ([object[]]): Array of sparse triples that passed both the
    #     minimum distinct principals threshold and the minimum total count
    #     threshold.
    #   - Dropped ([object[]]): Array of sparse triples that failed at
    #     least one threshold.
    #   - Stats ([object[]]): Array of per-action statistics produced by
    #     Get-ActionStatFromCount, each containing Action, TotalCount, and
    #     DistinctPrincipals properties.
    # This function does not return $null because the Counts parameter is
    # mandatory.
    # .NOTES
    # Requires Get-ActionStatFromCount to be loaded.
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
    #   Position 0: Counts
    #
    # Version: 1.1.20260410.1

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'The "Remove-" verb filters an in-memory collection and returns a new result object; it does not mutate any external or system state that would warrant ShouldProcess support.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Counts,

        [int]$MinDistinctPrincipals = 2,
        [double]$MinTotalCount = 10
    )

    process {
        Write-Verbose ("Pruning rare actions: MinDistinctPrincipals={0}, MinTotalCount={1}, InputCount={2}" -f $MinDistinctPrincipals, $MinTotalCount, $Counts.Count)
        try {
            $arrStats = @(Get-ActionStatFromCount -Counts $Counts)
            $hashKeep = @{}

            Write-Debug ("Stats computed: {0} distinct action(s) evaluated." -f $arrStats.Count)

            foreach ($objStat in $arrStats) {
                if ($objStat.DistinctPrincipals -ge $MinDistinctPrincipals -and $objStat.TotalCount -ge $MinTotalCount) {
                    $hashKeep[[string]$objStat.Action] = $true
                }
            }

            $arrKept = @($Counts | Where-Object { $hashKeep.ContainsKey([string]$_.Action) })
            $arrDropped = @($Counts | Where-Object { -not $hashKeep.ContainsKey([string]$_.Action) })

            Write-Debug ("Actions passing thresholds: {0}. Kept triples: {1}, Dropped triples: {2}." -f $hashKeep.Count, $arrKept.Count, $arrDropped.Count)

            [pscustomobject]@{
                Kept = $arrKept
                Dropped = $arrDropped
                Stats = $arrStats
            }
        } catch {
            Write-Debug ("Remove-RareAction failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
