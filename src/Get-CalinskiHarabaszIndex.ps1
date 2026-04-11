Set-StrictMode -Version Latest

function Get-CalinskiHarabaszIndex {
    # .SYNOPSIS
    # Computes the Calinski-Harabasz index for a K-Means clustering result.
    # .DESCRIPTION
    # The Calinski-Harabasz index (Variance Ratio Criterion) measures the
    # ratio of between-cluster dispersion to within-cluster dispersion.
    # Higher values indicate better-defined clusters. It is computed as:
    # (BGSS / (K - 1)) / (WGSS / (N - K)), where BGSS is the
    # between-group sum of squares and WGSS is the within-group sum of
    # squares.
    # .PARAMETER VectorRows
    # An array of vector row objects with PrincipalKey and Vector
    # properties.
    # .PARAMETER KMeansResult
    # A K-Means result object from Invoke-KMeansClustering.
    # .EXAMPLE
    # $dblCh = Get-CalinskiHarabaszIndex -VectorRows $arrRows -KMeansResult $objKm
    # # Higher is better.
    #
    # # Computes the Calinski-Harabasz index for a K-Means clustering result
    # # stored in $objKm against the original vector rows in $arrRows.
    # # A higher value indicates better-defined, well-separated clusters.
    #
    # .EXAMPLE
    # $objKMeans = [pscustomobject]@{
    #     K = 1
    #     Assignments = @{ 'a' = 0 }
    #     Centroids = @([double[]]@(1.0))
    #     SSE = 0.0
    # }
    # $arrRows = @(
    #     [pscustomobject]@{ PrincipalKey = 'a'; Vector = [double[]]@(1.0) }
    # )
    # $dblCh = Get-CalinskiHarabaszIndex -VectorRows $arrRows -KMeansResult $objKMeans
    # # Returns 0.0
    #
    # # When K-Means produces only a single cluster (K < 2), the function
    # # returns 0.0 because the Calinski-Harabasz index is undefined for a
    # # single cluster. At least two clusters are required to compute
    # # between-cluster vs. within-cluster dispersion.
    #
    # .EXAMPLE
    # $arrRows = @(
    #     [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
    #     [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.0, 0.0) }
    #     [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(10.0, 10.0) }
    #     [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(10.0, 10.0) }
    # )
    # $objKMeans = [pscustomobject]@{
    #     K = 2
    #     Assignments = @{ 'a1' = 0; 'a2' = 0; 'b1' = 1; 'b2' = 1 }
    #     Centroids = @([double[]]@(0.0, 0.0), [double[]]@(10.0, 10.0))
    #     SSE = 0.0
    # }
    # $dblCh = Get-CalinskiHarabaszIndex -VectorRows $arrRows -KMeansResult $objKMeans
    # # Returns [double]::PositiveInfinity
    #
    # # When all data points lie exactly on their cluster centroids, the
    # # within-group sum of squares (WGSS) is 0. Dividing by zero WGSS
    # # yields infinity. This indicates perfect clustering where every
    # # point matches its centroid exactly.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [double]
    # The function returns one of the following values:
    #   - A positive double value: the computed Calinski-Harabasz index
    #     (higher values indicate better-defined, well-separated clusters)
    #   - 0.0: returned when K < 2 or when N <= K (insufficient clusters or
    #     data for meaningful computation; the index is undefined)
    #   - [double]::PositiveInfinity: returned when WGSS (within-group sum of
    #     squares) is 0.0 (all points lie exactly on their cluster centroids)
    #   - -1.0: returned on unexpected computation failure (a Write-Warning
    #     message is also emitted); this value is never produced in normal
    #     operation and indicates an internal error
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
    # Version: 1.1.20260410.0

    [CmdletBinding()]
    [OutputType([double])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$VectorRows,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$KMeansResult
    )

    process {
        $intK = $KMeansResult.K
        $intN = $VectorRows.Count

        Write-Verbose ("Computing CH index: K={0}, N={1}" -f $intK, $intN)

        if ($intK -lt 2 -or $intN -le $intK) {
            if ($intK -lt 2) {
                Write-Debug "K < 2: returning 0.0 (CH index undefined for single cluster)"
            } else {
                Write-Debug "N <= K: returning 0.0 (insufficient data points)"
            }
            return 0.0
        }

        try {
            $intDimension = $VectorRows[0].Vector.Length

            # Compute global centroid
            $arrGlobalCentroid = New-Object double[] $intDimension
            for ($intPointIndex = 0; $intPointIndex -lt $intN; $intPointIndex++) {
                $arrVector = $VectorRows[$intPointIndex].Vector
                for ($intFeatureIndex = 0; $intFeatureIndex -lt $intDimension; $intFeatureIndex++) {
                    $arrGlobalCentroid[$intFeatureIndex] += $arrVector[$intFeatureIndex]
                }
            }
            for ($intFeatureIndex = 0; $intFeatureIndex -lt $intDimension; $intFeatureIndex++) {
                $arrGlobalCentroid[$intFeatureIndex] /= $intN
            }

            # Build cluster membership counts
            $arrClusterCounts = New-Object int[] $intK
            for ($intPointIndex = 0; $intPointIndex -lt $intN; $intPointIndex++) {
                $strKey = [string]$VectorRows[$intPointIndex].PrincipalKey
                $intClusterId = [int]$KMeansResult.Assignments[$strKey]
                $arrClusterCounts[$intClusterId]++
            }

            # BGSS: sum over clusters of n_k * ||centroid_k - global_centroid||^2
            $dblBgss = 0.0
            for ($intClusterIndex = 0; $intClusterIndex -lt $intK; $intClusterIndex++) {
                if ($arrClusterCounts[$intClusterIndex] -eq 0) {
                    continue
                }
                $dblDist = Get-SquaredEuclideanDistance -VectorA $KMeansResult.Centroids[$intClusterIndex] -VectorB $arrGlobalCentroid
                $dblBgss += $arrClusterCounts[$intClusterIndex] * $dblDist
            }

            # WGSS is the SSE from the K-Means result
            $dblWgss = $KMeansResult.SSE

            if ($dblWgss -eq 0.0) {
                Write-Debug "WGSS = 0: returning PositiveInfinity"
                return [double]::PositiveInfinity
            }

            $dblChIndex = ($dblBgss / ($intK - 1)) / ($dblWgss / ($intN - $intK))
            Write-Debug ("BGSS={0}, WGSS={1}, CH={2}" -f $dblBgss, $dblWgss, $dblChIndex)
            $dblChIndex
        } catch {
            Write-Debug "Get-CalinskiHarabaszIndex failed: $($_.Exception.Message)"
            Write-Warning "Get-CalinskiHarabaszIndex: Unexpected computation failure. Returning -1.0."
            return -1.0
        }
    }
}
