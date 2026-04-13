Set-StrictMode -Version Latest

function Get-FarthestPointIndex {
    # .SYNOPSIS
    # Finds the index of the vector row farthest from all current
    # centroids.
    # .DESCRIPTION
    # Scans all vector rows and returns the index of the point whose
    # nearest centroid distance is the greatest. Used to reseed empty
    # clusters during K-Means iteration.
    # .PARAMETER VectorRows
    # An array of vector row objects with a Vector property.
    # .PARAMETER Centroids
    # A collection of centroid vectors. Must be passed as a
    # System.Collections.Generic.List[double[]] to preserve .Count and
    # indexing semantics. PowerShell's @() unrolls a single [double[]]
    # element into a flat array, breaking .Count when only one centroid
    # is provided. Use New-Object or cast syntax to construct the list.
    # .EXAMPLE
    # $intIndex = Get-FarthestPointIndex -VectorRows $arrRows -Centroids $listCentroids
    # .EXAMPLE
    # $arrRows = @(
    #     [pscustomobject]@{ Vector = [double[]]@(0.0, 0.0) }
    #     [pscustomobject]@{ Vector = [double[]]@(1.0, 0.0) }
    #     [pscustomobject]@{ Vector = [double[]]@(10.0, 0.0) }
    # )
    # $listCentroids = New-Object 'System.Collections.Generic.List[double[]]'
    # $listCentroids.Add([double[]]@(0.0, 0.0))
    # $intResult = Get-FarthestPointIndex -VectorRows $arrRows -Centroids $listCentroids
    # # Returns: 2
    # # The point at index 2 (10.0, 0.0) is the farthest from the single
    # # centroid at (0.0, 0.0). Its squared distance is 100.0, compared to
    # # 0.0 for index 0 and 1.0 for index 1.
    # .EXAMPLE
    # $arrRows = @(
    #     [pscustomobject]@{ Vector = [double[]]@(5.0, 0.0) }
    #     [pscustomobject]@{ Vector = [double[]]@(0.0, 3.0) }
    #     [pscustomobject]@{ Vector = [double[]]@(2.5, 2.5) }
    # )
    # $listCentroids = New-Object 'System.Collections.Generic.List[double[]]'
    # $listCentroids.Add([double[]]@(0.0, 0.0))
    # $listCentroids.Add([double[]]@(5.0, 0.0))
    # $intResult = Get-FarthestPointIndex -VectorRows $arrRows -Centroids $listCentroids
    # # Returns: 2
    # # With two centroids at (0,0) and (5,0), each point's nearest-centroid
    # # squared distance is: index 0 = 0.0 (on centroid (5,0)), index 1 =
    # # 9.0 (nearest is (0,0)), index 2 = 12.5 (equidistant from both
    # # centroids). Although index 1 has the greatest distance from a single
    # # centroid (34.0 to (5,0)), its nearest-centroid distance is only 9.0.
    # # Index 2 has the greatest nearest-centroid distance (12.5), so it is
    # # selected as the farthest point.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [int] A zero-based index into the $VectorRows array identifying the
    # point whose nearest-centroid squared distance is the greatest. When
    # all points are equidistant from their nearest centroid, the function
    # returns 0 (the first index encountered, due to the > comparison).
    # .NOTES
    # Requires Get-SquaredEuclideanDistance to be loaded.
    # Version: 1.1.20260410.1
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
    #   Position 0: VectorRows
    #   Position 1: Centroids

    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$VectorRows,

        [Parameter(Mandatory = $true)]
        [object]$Centroids
    )

    process {
        $intBestIndex = 0
        $dblBestDistance = -1.0

        try {
            Write-Verbose ("Scanning {0} vector rows against {1} centroids for farthest point" -f $VectorRows.Count, $Centroids.Count)

            for ($intRowIndex = 0; $intRowIndex -lt $VectorRows.Count; $intRowIndex++) {
                $arrVector = $VectorRows[$intRowIndex].Vector

                $dblNearest = [double]::PositiveInfinity
                for ($intCentroidIndex = 0; $intCentroidIndex -lt $Centroids.Count; $intCentroidIndex++) {
                    $dblDistance = Get-SquaredEuclideanDistance -VectorA $arrVector -VectorB $Centroids[$intCentroidIndex]
                    if ($dblDistance -lt $dblNearest) {
                        $dblNearest = $dblDistance
                    }
                }

                if ($dblNearest -gt $dblBestDistance) {
                    $dblBestDistance = $dblNearest
                    $intBestIndex = $intRowIndex
                }
            }

            Write-Verbose ("Farthest point index: {0} (nearest-centroid distance: {1})" -f $intBestIndex, $dblBestDistance)

            $intBestIndex
        } catch {
            Write-Debug ("Failed to find farthest point index: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
