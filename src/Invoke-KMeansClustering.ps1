Set-StrictMode -Version Latest

function Invoke-KMeansClustering {
    # .SYNOPSIS
    # Performs K-Means clustering on vector rows with deterministic seeding.
    # .DESCRIPTION
    # Clusters vector rows into K groups using Lloyd's algorithm with
    # random initialization from a fixed seed for reproducibility. Empty
    # clusters are reseeded using the farthest-point heuristic. Returns
    # the cluster assignments, centroids, and sum of squared errors (SSE).
    # .PARAMETER VectorRows
    # An array of vector row objects with PrincipalKey and Vector
    # properties.
    # .PARAMETER NumberOfClusters
    # The number of clusters to form. Must be between 2 and N.
    # .PARAMETER MaxIterations
    # Maximum number of Lloyd iterations. Default is 50.
    # .PARAMETER Seed
    # Random seed for deterministic initialization. Default is 42.
    # .EXAMPLE
    # $objResult = Invoke-KMeansClustering -VectorRows $arrRows -NumberOfClusters 5
    # # $objResult.K = 5
    # # $objResult.Assignments is a hashtable mapping PrincipalKey to cluster ID
    # # $objResult.Centroids is a list of centroid vectors
    # # $objResult.SSE is the sum of squared errors
    # .EXAMPLE
    # $objResult = Invoke-KMeansClustering -VectorRows $arrRows -K 3 -MaxIterations 100 -Seed 7
    # # Returns a [pscustomobject] with the following properties:
    # # $objResult.K -- the number of clusters requested (3)
    # # $objResult.Assignments -- a [hashtable] mapping each PrincipalKey
    # #     (string) to its zero-based cluster index (integer)
    # # $objResult.Centroids -- a [System.Collections.Generic.List[double[]]]
    # #     containing the centroid vectors for each cluster
    # # $objResult.SSE -- a [double] representing the sum of squared errors
    # #     across all clusters
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] A K-Means result object with the following
    # properties:
    #   - K ([int]): The number of clusters
    #   - Assignments ([hashtable]): Maps each PrincipalKey (string) to its
    #     cluster index (zero-based integer)
    #   - Centroids ([System.Collections.Generic.List[double[]]]): The
    #     centroid vectors for each cluster
    #   - SSE ([double]): The sum of squared errors across all clusters
    # .NOTES
    # Requires Get-SquaredEuclideanDistance and Get-FarthestPointIndex to
    # be loaded.
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
    #   Position 1: NumberOfClusters
    #   Position 2: MaxIterations
    #   Position 3: Seed
    #
    # Version: 1.2.20260413.0

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$VectorRows,

        [Parameter(Mandatory = $true)]
        [Alias('K')]
        [int]$NumberOfClusters,

        [int]$MaxIterations = 50,
        [int]$Seed = 42
    )

    process {
        Write-Verbose ("Invoke-KMeansClustering starting: {0} vector rows, K={1}" -f $VectorRows.Count, $NumberOfClusters)

        $intNumberOfVectorRows = $VectorRows.Count
        if ($NumberOfClusters -lt 2 -or $NumberOfClusters -gt $intNumberOfVectorRows) {
            throw ("NumberOfClusters must be between 2 and N ({0})." -f $intNumberOfVectorRows)
        }

        try {
            $objRandom = New-Object System.Random($Seed)

            # Initialize centroids by random selection
            $hashChosen = @{}
            $listCentroids = New-Object System.Collections.Generic.List[double[]]
            while ($listCentroids.Count -lt $NumberOfClusters) {
                $intCandidateCentroidIndex = $objRandom.Next(0, $intNumberOfVectorRows)
                if (-not $hashChosen.ContainsKey($intCandidateCentroidIndex)) {
                    $hashChosen[$intCandidateCentroidIndex] = $true
                    $arrSourceVector = $VectorRows[$intCandidateCentroidIndex].Vector
                    $arrCentroid = New-Object double[] $arrSourceVector.Length
                    [Array]::Copy($arrSourceVector, $arrCentroid, $arrSourceVector.Length)
                    [void]($listCentroids.Add($arrCentroid))
                }
            }
            Write-Debug ("Initialized {0} centroids" -f $listCentroids.Count)

            $arrAssignments = New-Object int[] $intNumberOfVectorRows
            for ($intPointIndex = 0; $intPointIndex -lt $intNumberOfVectorRows; $intPointIndex++) {
                $arrAssignments[$intPointIndex] = -1
            }

            $intDimension = $VectorRows[0].Vector.Length

            for ($intIteration = 0; $intIteration -lt $MaxIterations; $intIteration++) {
                $boolAssignmentsChanged = $false

                # Assignment step
                for ($intPointIndex = 0; $intPointIndex -lt $intNumberOfVectorRows; $intPointIndex++) {
                    $arrCurrentPointVector = $VectorRows[$intPointIndex].Vector
                    $intBestCluster = 0
                    $dblBestSquaredDistance = [double]::PositiveInfinity

                    for ($intClusterIndex = 0; $intClusterIndex -lt $NumberOfClusters; $intClusterIndex++) {
                        $dblCurrentSquaredDistance = Get-SquaredEuclideanDistance -VectorA $arrCurrentPointVector -VectorB $listCentroids[$intClusterIndex]
                        if ($dblCurrentSquaredDistance -lt $dblBestSquaredDistance) {
                            $dblBestSquaredDistance = $dblCurrentSquaredDistance
                            $intBestCluster = $intClusterIndex
                        }
                    }

                    if ($arrAssignments[$intPointIndex] -ne $intBestCluster) {
                        $arrAssignments[$intPointIndex] = $intBestCluster
                        $boolAssignmentsChanged = $true
                    }
                }

                # Update step
                $listNewCentroids = New-Object System.Collections.Generic.List[double[]]
                $arrClusterCounts = New-Object int[] $NumberOfClusters
                for ($intClusterIndex = 0; $intClusterIndex -lt $NumberOfClusters; $intClusterIndex++) {
                    [void]($listNewCentroids.Add((New-Object double[] $intDimension)))
                    $arrClusterCounts[$intClusterIndex] = 0
                }

                for ($intPointIndex = 0; $intPointIndex -lt $intNumberOfVectorRows; $intPointIndex++) {
                    $intAssignedCluster = $arrAssignments[$intPointIndex]
                    $arrClusterCounts[$intAssignedCluster]++
                    $arrCurrentPointVector = $VectorRows[$intPointIndex].Vector
                    for ($intFeatureIndex = 0; $intFeatureIndex -lt $intDimension; $intFeatureIndex++) {
                        $listNewCentroids[$intAssignedCluster][$intFeatureIndex] += $arrCurrentPointVector[$intFeatureIndex]
                    }
                }

                for ($intClusterIndex = 0; $intClusterIndex -lt $NumberOfClusters; $intClusterIndex++) {
                    if ($arrClusterCounts[$intClusterIndex] -gt 0) {
                        for ($intFeatureIndex = 0; $intFeatureIndex -lt $intDimension; $intFeatureIndex++) {
                            $listNewCentroids[$intClusterIndex][$intFeatureIndex] /= $arrClusterCounts[$intClusterIndex]
                        }
                        $listCentroids[$intClusterIndex] = $listNewCentroids[$intClusterIndex]
                    } else {
                        # Reseed empty cluster with farthest point
                        $intFarthestPointIndex = Get-FarthestPointIndex -VectorRows $VectorRows -Centroids $listCentroids
                        $arrSourceVector = $VectorRows[$intFarthestPointIndex].Vector
                        $arrCentroid = New-Object double[] $intDimension
                        [Array]::Copy($arrSourceVector, $arrCentroid, $intDimension)
                        $listCentroids[$intClusterIndex] = $arrCentroid
                    }
                }

                if (-not $boolAssignmentsChanged) {
                    Write-Verbose ("K-Means converged at iteration {0}" -f ($intIteration + 1))
                    break
                }
            }

            # Compute SSE
            $dblSumOfSquaredErrors = 0.0
            for ($intPointIndex = 0; $intPointIndex -lt $intNumberOfVectorRows; $intPointIndex++) {
                $intAssignedCluster = $arrAssignments[$intPointIndex]
                $dblSumOfSquaredErrors += Get-SquaredEuclideanDistance -VectorA $VectorRows[$intPointIndex].Vector -VectorB $listCentroids[$intAssignedCluster]
            }
            Write-Debug ("Computed SSE = {0}" -f $dblSumOfSquaredErrors)

            # Build assignment map
            $hashAssignmentMap = @{}
            for ($intPointIndex = 0; $intPointIndex -lt $intNumberOfVectorRows; $intPointIndex++) {
                $hashAssignmentMap[[string]$VectorRows[$intPointIndex].PrincipalKey] = [int]$arrAssignments[$intPointIndex]
            }

            [pscustomobject]@{
                K = $NumberOfClusters
                Assignments = $hashAssignmentMap
                Centroids = $listCentroids
                SSE = [double]$dblSumOfSquaredErrors
            }
        } catch {
            Write-Debug ("Invoke-KMeansClustering failed: {0}" -f $(if ($_.Exception.Message) { $_.Exception.Message } else { $_.ToString() }))
            throw
        }
    }
}
