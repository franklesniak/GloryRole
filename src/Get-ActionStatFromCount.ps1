Set-StrictMode -Version Latest

function Get-ActionStatFromCount {
    # .SYNOPSIS
    # Computes per-action statistics from principal-action counts.
    # .DESCRIPTION
    # Calculates total count and distinct principal count for each action
    # in a set of PrincipalActionCount sparse triples. Used to inform
    # pruning decisions.
    # .PARAMETER Counts
    # An array of PrincipalActionCount sparse triples.
    # .EXAMPLE
    # $arrStats = @(Get-ActionStatFromCount -Counts $arrCounts)
    # # $arrStats[0].Action = 'microsoft.compute/virtualmachines/read'
    # # $arrStats[0].TotalCount = 150.0
    # # $arrStats[0].DistinctPrincipals = 12
    # .EXAMPLE
    # $arrSingleStat = @(Get-ActionStatFromCount -Counts @(
    #     [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'microsoft.storage/storageaccounts/read'; Count = 5.0 }
    # ))
    # # $arrSingleStat[0].Action = 'microsoft.storage/storageaccounts/read'
    # # $arrSingleStat[0].TotalCount = 5.0
    # # $arrSingleStat[0].DistinctPrincipals = 1
    # # # Demonstrates minimal usage with a single action from a single
    # # # principal. Both TotalCount and DistinctPrincipals reflect the
    # # # single input row.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] Action statistics with TotalCount and
    # DistinctPrincipals.
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
    # If any input row is malformed the function writes a non-terminating
    # error and skips the invalid row. Callers that need to halt on error
    # should use -ErrorAction Stop.
    #
    # This function supports positional parameters:
    #   Position 0: Counts
    #
    # Version: 1.2.20260412.0

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Counts
    )

    process {
        try {
            Write-Verbose ("Processing {0} input row(s)." -f $Counts.Count)

            $hashTotal = @{}
            $hashPrincipalSet = @{}

            foreach ($objRow in $Counts) {
                # Validate required properties
                if ($null -eq $objRow.PSObject -or
                    -not $objRow.PSObject.Properties['Action'] -or
                    -not $objRow.PSObject.Properties['PrincipalKey'] -or
                    -not $objRow.PSObject.Properties['Count']) {
                    Write-Error "Input row is missing one or more required properties (Action, PrincipalKey, Count)."
                    continue
                }

                # Validate Count can be cast to double
                $dblCount = $null
                try {
                    $dblCount = [double]$objRow.Count
                } catch {
                    Write-Error ("Input row has a non-numeric Count value: '{0}'." -f $objRow.Count)
                    continue
                }

                $strAction = [string]$objRow.Action
                $strPrincipal = [string]$objRow.PrincipalKey

                if ($hashTotal.ContainsKey($strAction)) {
                    $hashTotal[$strAction] += $dblCount
                } else {
                    $hashTotal[$strAction] = $dblCount
                }

                if (-not $hashPrincipalSet.ContainsKey($strAction)) {
                    $hashPrincipalSet[$strAction] = @{}
                }
                $hashPrincipalSet[$strAction][$strPrincipal] = $true
            }

            foreach ($strAction in $hashTotal.Keys) {
                [pscustomobject]@{
                    Action = $strAction
                    TotalCount = [double]$hashTotal[$strAction]
                    DistinctPrincipals = [int]$hashPrincipalSet[$strAction].Count
                }
            }
        } catch {
            Write-Debug ("Get-ActionStatFromCount failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
