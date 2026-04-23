Set-StrictMode -Version Latest

function Get-DaviesBouldinIndex {
    # .SYNOPSIS
    # Computes the Davies-Bouldin index for a K-Means clustering result.
    # .DESCRIPTION
    # The Davies-Bouldin index measures average cluster similarity, where
    # similarity is the ratio of within-cluster scatter to between-cluster
    # separation. Lower values indicate better-defined clusters. For each
    # cluster, the worst-case (highest) similarity ratio with any other
    # cluster is found, then all worst-case ratios are averaged.
    # .PARAMETER VectorRows
    # An array of vector row objects with PrincipalKey and Vector
    # properties.
    # .PARAMETER KMeansResult
    # A K-Means result object from Invoke-KMeansClustering.
    # .EXAMPLE
    # $dblDb = Get-DaviesBouldinIndex -VectorRows $arrRows -KMeansResult $objKm
    # # Lower is better; 0 is perfect.
    # .EXAMPLE
    # $objSingleCluster = [pscustomobject]@{
    #     K = 1
    #     Assignments = @{ 'a' = 0 }
    #     Centroids = @([double[]]@(1.0))
    #     SSE = 0.0
    # }
    # $dblDb = Get-DaviesBouldinIndex -VectorRows $arrRows -KMeansResult $objSingleCluster
    # # Returns 0.0 because the Davies-Bouldin index is undefined for
    # # fewer than two clusters. When K < 2, the function returns 0.0
    # # without computing the metric.
    # .EXAMPLE
    # $objCoincident = [pscustomobject]@{
    #     K = 2
    #     Assignments = @{ 'a1' = 0; 'a2' = 0; 'b1' = 1; 'b2' = 1 }
    #     Centroids = @([double[]]@(1.0, 2.0), [double[]]@(1.0, 2.0))
    #     SSE = 0.5
    # }
    # $dblDb = Get-DaviesBouldinIndex -VectorRows $arrRows -KMeansResult $objCoincident
    # # Returns [double]::PositiveInfinity because the two cluster
    # # centroids are identical (coincident). Dividing the sum of
    # # scatter values by a zero inter-centroid distance yields infinity.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [double]
    # The function returns one of the following values:
    #   - A non-negative double value: the computed Davies-Bouldin index
    #     (lower values indicate better-defined, well-separated clusters;
    #     0 is theoretically perfect)
    #   - 0.0: returned without computing the metric when K < 2
    #     (the Davies-Bouldin index is undefined for fewer than two clusters)
    #   - [double]::PositiveInfinity: returned when at least one pair of
    #     clusters has coincident centroids (zero inter-centroid distance),
    #     indicating a degenerate configuration
    # .NOTES
    # Requires Get-SquaredEuclideanDistance to be loaded.
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
    #   Position 0: VectorRows
    #   Position 1: KMeansResult
    #
    # Version: 1.1.20260422.0

    [CmdletBinding()]
    [OutputType([double])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$VectorRows,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$KMeansResult
    )

    process {
        try {
            $intK = $KMeansResult.K
            $intN = $VectorRows.Count
            Write-Verbose ("Computing Davies-Bouldin index: K={0}, N={1}" -f $intK, $intN)

            if ($intK -lt 2) {
                return 0.0
            }

            # Build cluster membership lists
            $hashtableMembers = @{}
            for ($intClusterIndex = 0; $intClusterIndex -lt $intK; $intClusterIndex++) {
                $hashtableMembers[$intClusterIndex] = New-Object System.Collections.Generic.List[int]
            }

            for ($intPointIndex = 0; $intPointIndex -lt $intN; $intPointIndex++) {
                $strKey = [string]$VectorRows[$intPointIndex].PrincipalKey
                $intClusterId = [int]$KMeansResult.Assignments[$strKey]
                [void]($hashtableMembers[$intClusterId].Add($intPointIndex))
            }

            # Compute scatter (average distance to centroid) for each cluster
            $arrScatter = New-Object double[] $intK
            for ($intClusterIndex = 0; $intClusterIndex -lt $intK; $intClusterIndex++) {
                $listIndices = $hashtableMembers[$intClusterIndex]
                if ($listIndices.Count -eq 0) {
                    $arrScatter[$intClusterIndex] = 0.0
                    continue
                }

                $dblSum = 0.0
                $arrCentroid = $KMeansResult.Centroids[$intClusterIndex]
                foreach ($intIdx in $listIndices) {
                    $dblSum += [Math]::Sqrt(
                        (Get-SquaredEuclideanDistance -VectorA $VectorRows[$intIdx].Vector -VectorB $arrCentroid)
                    )
                }
                $arrScatter[$intClusterIndex] = $dblSum / $listIndices.Count
            }

            # Compute DB index: average of max similarity ratios
            $dblDbSum = 0.0
            for ($intI = 0; $intI -lt $intK; $intI++) {
                $dblMaxRatio = 0.0
                for ($intJ = 0; $intJ -lt $intK; $intJ++) {
                    if ($intI -eq $intJ) {
                        continue
                    }

                    $dblCentroidDist = [Math]::Sqrt(
                        (Get-SquaredEuclideanDistance -VectorA $KMeansResult.Centroids[$intI] -VectorB $KMeansResult.Centroids[$intJ])
                    )

                    if ($dblCentroidDist -gt 0) {
                        $dblRatio = ($arrScatter[$intI] + $arrScatter[$intJ]) / $dblCentroidDist
                    } else {
                        if ($intI -lt $intJ) {
                            Write-Warning ("Centroids for clusters {0} and {1} are coincident; ratio set to Infinity." -f $intI, $intJ)
                        }
                        $dblRatio = [double]::PositiveInfinity
                    }

                    if ($dblRatio -gt $dblMaxRatio) {
                        $dblMaxRatio = $dblRatio
                    }
                }
                $dblDbSum += $dblMaxRatio
            }

            $dblDbIndex = $dblDbSum / $intK
            Write-Verbose ("Davies-Bouldin index = {0}" -f $dblDbIndex)
            return $dblDbIndex
        } catch {
            Write-Debug ("Get-DaviesBouldinIndex failed: {0}" -f $(if ($_.Exception.Message) { $_.Exception.Message } else { $_.ToString() }))
            throw
        }
    }
}
