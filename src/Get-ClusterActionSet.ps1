Set-StrictMode -Version Latest

function Get-ClusterActionSet {
    # .SYNOPSIS
    # Extracts the set of unique actions per cluster from principal-action
    # counts and cluster assignments.
    # .DESCRIPTION
    # Maps each cluster to its constituent actions by looking up each
    # principal's cluster assignment and collecting the distinct actions
    # performed by principals in that cluster. Uses the original (pre-
    # vectorization) sparse triples to ensure RBAC fidelity. The output
    # represents the aggregated permission set for each cluster, suitable
    # for constructing Azure custom role definitions. Principals present
    # in Counts but absent from AssignmentsMap are skipped (a Debug
    # message is emitted for each skipped principal).
    # .PARAMETER Counts
    # An array of PrincipalActionCount sparse triples.
    # .PARAMETER AssignmentsMap
    # A hashtable mapping PrincipalKey to cluster ID (from K-Means
    # result).
    # .EXAMPLE
    # $arrClusterActions = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $objKm.Assignments)
    # # $arrClusterActions[0].ClusterId = 0
    # # $arrClusterActions[0].Actions = @('microsoft.compute/virtualmachines/read', ...)
    # .EXAMPLE
    # $arrCounts = @(
    # #     [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
    # #     [pscustomobject]@{ PrincipalKey = 'unknownUser'; Action = 'write'; Count = 2 }
    # # )
    # # $hashAssignments = @{ 'userA' = 0 }
    # $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)
    # # # 'unknownUser' is not in $hashAssignments, so it is skipped.
    # # # $arrResult.Count = 1
    # # # $arrResult[0].ClusterId = 0
    # # # $arrResult[0].Actions = @('read')
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] Objects with the following properties:
    #   - ClusterId ([int]) - The cluster identifier from the assignments
    #     map.
    #   - Actions ([string[]]) - A sorted array of unique action strings
    #     belonging to principals assigned to this cluster.
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
    #   Position 0: Counts
    #   Position 1: AssignmentsMap
    #
    # Version: 2.0.20260410.0

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Counts,

        [Parameter(Mandatory = $true)]
        [hashtable]$AssignmentsMap
    )

    process {
        try {
            $intCountRecords = if ($null -ne $Counts) { $Counts.Count } else { 0 }
            $intAssignmentCount = if ($null -ne $AssignmentsMap) { $AssignmentsMap.Count } else { 0 }
            Write-Verbose ("Processing {0} count records against {1} cluster assignments." -f $intCountRecords, $intAssignmentCount)

            $hashActionsByCluster = @{}

            foreach ($objRow in $Counts) {
                $strPrincipal = [string]$objRow.PrincipalKey
                if (-not $AssignmentsMap.ContainsKey($strPrincipal)) {
                    Write-Debug "Principal not found in AssignmentsMap, skipping."
                    continue
                }
                $intClusterId = [int]$AssignmentsMap[$strPrincipal]

                if (-not $hashActionsByCluster.ContainsKey($intClusterId)) {
                    $hashActionsByCluster[$intClusterId] = @{}
                }
                $hashActionsByCluster[$intClusterId][[string]$objRow.Action] = $true
            }

            foreach ($intClusterId in ($hashActionsByCluster.Keys | Sort-Object)) {
                [pscustomobject]@{
                    ClusterId = $intClusterId
                    Actions = [string[]]@($hashActionsByCluster[$intClusterId].Keys | Sort-Object)
                }
            }
        } catch {
            $strErrorMessage = $null
            if ($null -ne $_ -and $null -ne $_.Exception -and
                    -not [string]::IsNullOrEmpty($_.Exception.Message)) {
                $strErrorMessage = $_.Exception.Message
            } else {
                $strErrorMessage = ($_ | Out-String)
            }
            Write-Debug ("Failed to process cluster actions: {0}" -f $strErrorMessage)
            throw
        }
    }
}
