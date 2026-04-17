Set-StrictMode -Version Latest

function Get-ClusterActionSet {
    # .SYNOPSIS
    # Extracts the set of unique actions and principals per cluster from
    # principal-action counts and cluster assignments.
    # .DESCRIPTION
    # Maps each cluster to its constituent actions and principals by
    # looking up each principal's cluster assignment and collecting the
    # distinct actions performed by principals in that cluster. Uses the
    # original (pre-vectorization) sparse triples to ensure RBAC fidelity.
    # The output represents the aggregated permission set and contributing
    # principals for each cluster, suitable for constructing Azure custom
    # role definitions and downstream role assignment. Principals present
    # in Counts but absent from AssignmentsMap are skipped (a Debug
    # message is emitted for each such skipped count record, so a
    # principal that appears on multiple rows can produce multiple
    # messages).
    #
    # When a **non-empty** PrincipalDisplayNameMap is supplied, each
    # output object also includes a PrincipalDisplayNames property
    # containing human-readable names (e.g. UPNs) for the principals in
    # that cluster. Principals not found in the map are included by
    # their PrincipalKey value. When the map is omitted, `$null`, or
    # empty (Count -eq 0), the PrincipalDisplayNames property is
    # **not** added to output objects; callers should test with
    # PSObject.Properties.Match or Get-Member rather than assuming the
    # property is always present.
    # .PARAMETER Counts
    # An array of PrincipalActionCount sparse triples.
    # .PARAMETER AssignmentsMap
    # A hashtable mapping PrincipalKey to cluster ID (from K-Means
    # result).
    # .PARAMETER PrincipalDisplayNameMap
    # An optional hashtable mapping PrincipalKey to a human-readable
    # display name (e.g. UserPrincipalName, app display name). When
    # provided **and non-empty** (Count -gt 0), each output object
    # includes a PrincipalDisplayNames property. Principals not present
    # in the map are represented by their PrincipalKey value. An
    # omitted, `$null`, or empty map causes the property to be absent
    # from output (callers should not assume it is always present).
    # .EXAMPLE
    # $arrClusterActions = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $objKm.Assignments)
    # # $arrClusterActions[0].ClusterId = 0
    # # $arrClusterActions[0].Actions = @('microsoft.compute/virtualmachines/read', ...)
    # # $arrClusterActions[0].Principals = @('user1@contoso.com', 'spn-abcde')
    # .EXAMPLE
    # $hashDisplayNames = @{ '00000000-0000-0000-0000-000000000001' = 'admin@contoso.com'; 'app-id-123' = 'app-id-123' }
    # $arrClusterActions = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $objKm.Assignments -PrincipalDisplayNameMap $hashDisplayNames)
    # # $arrClusterActions[0].PrincipalDisplayNames = @('admin@contoso.com')
    # .EXAMPLE
    # $arrCounts = @(
    # #     [pscustomobject]@{ PrincipalKey = 'userA'; Action = 'read'; Count = 1 }
    # #     [pscustomobject]@{ PrincipalKey = 'unknownUser'; Action = 'write'; Count = 2 }
    # # )
    # # $hashAssignments = @{ 'userA' = 0 }
    # $arrResult = @(Get-ClusterActionSet -Counts $arrCounts -AssignmentsMap $hashAssignments)
    # # 'unknownUser' is not in $hashAssignments, so it is skipped.
    # # $arrResult.Count = 1
    # # $arrResult[0].ClusterId = 0
    # # $arrResult[0].Actions = @('read')
    # # $arrResult[0].Principals = @('userA')
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] Objects with the following properties:
    #   - ClusterId ([int]) - The cluster identifier from the assignments
    #     map.
    #   - Actions ([string[]]) - A sorted array of unique action strings
    #     belonging to principals assigned to this cluster.
    #   - Principals ([string[]]) - A sorted array of unique principal
    #     keys (users and service principals) assigned to this cluster.
    #   - PrincipalDisplayNames ([string[]]) - (Present only when
    #     PrincipalDisplayNameMap is supplied **and non-empty**.) A
    #     sorted array of human-readable names for each principal.
    #     Principals not in the map are represented by their
    #     PrincipalKey.
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
    # Version: 2.2.20260415.1

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Counts,

        [Parameter(Mandatory = $true)]
        [hashtable]$AssignmentsMap,

        [Parameter(Mandatory = $false)]
        [hashtable]$PrincipalDisplayNameMap
    )

    process {
        try {
            $intCountRecords = if ($null -ne $Counts) { $Counts.Count } else { 0 }
            $intAssignmentCount = if ($null -ne $AssignmentsMap) { $AssignmentsMap.Count } else { 0 }
            Write-Verbose ("Processing {0} count records against {1} cluster assignments." -f $intCountRecords, $intAssignmentCount)

            $hashActionsByCluster = @{}
            $hashPrincipalsByCluster = @{}

            foreach ($objRow in $Counts) {
                $strPrincipal = [string]$objRow.PrincipalKey
                if (-not $AssignmentsMap.ContainsKey($strPrincipal)) {
                    Write-Debug "Principal not found in AssignmentsMap, skipping."
                    continue
                }
                $intClusterId = [int]$AssignmentsMap[$strPrincipal]

                if (-not $hashActionsByCluster.ContainsKey($intClusterId)) {
                    $hashActionsByCluster[$intClusterId] = @{}
                    $hashPrincipalsByCluster[$intClusterId] = @{}
                }
                $hashActionsByCluster[$intClusterId][[string]$objRow.Action] = $true
                $hashPrincipalsByCluster[$intClusterId][$strPrincipal] = $true
            }

            foreach ($intClusterId in ($hashActionsByCluster.Keys | Sort-Object)) {
                $arrSortedPrincipals = [string[]]@($hashPrincipalsByCluster[$intClusterId].Keys | Sort-Object)

                $objOutput = [pscustomobject]@{
                    ClusterId = $intClusterId
                    Actions = [string[]]@($hashActionsByCluster[$intClusterId].Keys | Sort-Object)
                    Principals = $arrSortedPrincipals
                }

                # Append human-readable display names when a lookup map
                # was supplied. Principals not in the map fall back to
                # their PrincipalKey so no entry is silently dropped.
                if ($null -ne $PrincipalDisplayNameMap -and $PrincipalDisplayNameMap.Count -gt 0) {
                    $arrDisplayNames = [string[]]@(
                        foreach ($strPrincipalKey in $arrSortedPrincipals) {
                            if ($PrincipalDisplayNameMap.ContainsKey($strPrincipalKey)) {
                                [string]$PrincipalDisplayNameMap[$strPrincipalKey]
                            } else {
                                $strPrincipalKey
                            }
                        }
                    )
                    $arrDisplayNames = [string[]]@($arrDisplayNames | Sort-Object)
                    $objOutput | Add-Member -MemberType NoteProperty -Name 'PrincipalDisplayNames' -Value $arrDisplayNames
                }

                $objOutput
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
