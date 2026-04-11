Set-StrictMode -Version Latest

function Get-ApproximateSilhouetteScore {
    # .SYNOPSIS
    # Computes an approximate silhouette score for a K-Means result using
    # random sampling.
    # .DESCRIPTION
    # Calculates the mean silhouette coefficient over a random sample of
    # data points for scalability. The silhouette score measures cluster
    # quality: values near 1.0 indicate well-separated clusters, near 0
    # indicates overlapping clusters, and negative values indicate
    # misclassified points.
    # .PARAMETER VectorRows
    # An array of vector row objects with PrincipalKey and Vector
    # properties.
    # .PARAMETER KMeansResult
    # A K-Means result object from Invoke-KMeansClustering.
    # .PARAMETER SampleSize
    # Number of points to sample for the approximation. Default is 200.
    # .PARAMETER Seed
    # Random seed for reproducible sampling. Default is 42.
    # .EXAMPLE
    # $dblScore = Get-ApproximateSilhouetteScore -VectorRows $arrRows -KMeansResult $objKm
    # # # Returns a value between -1.0 and 1.0
    # # # Computes the approximate silhouette score using default SampleSize
    # # # (200) and Seed (42).
    # .EXAMPLE
    # $arrRows = @(
    #     [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(1.0, 2.0) }
    # )
    # $objKm = [pscustomobject]@{
    #     K = 1
    #     Assignments = @{ 'a1' = 0 }
    # }
    # $dblScore = Get-ApproximateSilhouetteScore -VectorRows $arrRows -KMeansResult $objKm
    # # # Returns: 0.0
    # # # When 2 or fewer data points are provided, the function's early-exit
    # # # guard returns 0.0 because a meaningful silhouette computation
    # # # requires at least 3 points.
    # .EXAMPLE
    # $arrRows = @(
    #     [pscustomobject]@{ PrincipalKey = 'a1'; Vector = [double[]]@(0.0, 0.0) }
    #     [pscustomobject]@{ PrincipalKey = 'a2'; Vector = [double[]]@(0.1, 0.1) }
    #     [pscustomobject]@{ PrincipalKey = 'a3'; Vector = [double[]]@(0.2, 0.0) }
    #     [pscustomobject]@{ PrincipalKey = 'b1'; Vector = [double[]]@(10.0, 10.0) }
    #     [pscustomobject]@{ PrincipalKey = 'b2'; Vector = [double[]]@(10.1, 10.1) }
    #     [pscustomobject]@{ PrincipalKey = 'b3'; Vector = [double[]]@(10.2, 10.0) }
    # )
    # $objKm = [pscustomobject]@{
    #     K = 2
    #     Assignments = @{ 'a1' = 0; 'a2' = 0; 'a3' = 0; 'b1' = 1; 'b2' = 1; 'b3' = 1 }
    # }
    # $dblScore = Get-ApproximateSilhouetteScore -VectorRows $arrRows -KMeansResult $objKm -SampleSize 6 -Seed 123
    # # # Returns a score close to 1.0 for well-separated clusters.
    # # # The -SampleSize parameter controls the number of points sampled for
    # # # computation (here all 6 points). The -Seed parameter ensures
    # # # reproducible sampling so repeated calls return the same result.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [double] The approximate mean silhouette score. Valid range is -1.0
    # to 1.0. Values near 1.0 indicate well-separated clusters. Values
    # near 0 indicate overlapping clusters. Negative values indicate
    # misclassified points. Returns 0.0 when 2 or fewer data points are
    # provided (early-exit edge case).
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
    #   Position 1: KMeansResult
    #   Position 2: SampleSize
    #   Position 3: Seed

    [CmdletBinding()]
    [OutputType([double])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$VectorRows,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$KMeansResult,

        [int]$SampleSize = 200,
        [int]$Seed = 42
    )

    process {
        $intN = $VectorRows.Count
        if ($intN -le 2) {
            return 0.0
        }

        try {
            Write-Verbose ("Computing silhouette score for {0} points, K={1}, sample size={2}" -f $intN, $KMeansResult.K, $SampleSize)

            # Build cluster membership lists
            $hashClusters = @{}
            for ($intK = 0; $intK -lt $KMeansResult.K; $intK++) {
                $hashClusters[$intK] = New-Object System.Collections.Generic.List[int]
            }

            for ($intI = 0; $intI -lt $intN; $intI++) {
                $strPrincipalKey = [string]$VectorRows[$intI].PrincipalKey
                $intClusterId = [int]$KMeansResult.Assignments[$strPrincipalKey]
                [void]($hashClusters[$intClusterId].Add($intI))
            }

            # Sample indices
            $objRandom = New-Object System.Random($Seed)
            $intSampleCount = [Math]::Min($SampleSize, $intN)
            $listSample = New-Object System.Collections.Generic.List[int]
            $hashPicked = @{}
            while ($listSample.Count -lt $intSampleCount) {
                $intIndex = $objRandom.Next(0, $intN)
                if (-not $hashPicked.ContainsKey($intIndex)) {
                    $hashPicked[$intIndex] = $true
                    [void]($listSample.Add($intIndex))
                }
            }

            Write-Verbose ("Sampled {0} points for silhouette computation" -f $listSample.Count)

            $dblSumSilhouette = 0.0
            foreach ($intI in $listSample) {
                $arrVector = $VectorRows[$intI].Vector
                $strPrincipalKey = [string]$VectorRows[$intI].PrincipalKey
                $intOwnCluster = [int]$KMeansResult.Assignments[$strPrincipalKey]

                # a: mean distance to own cluster
                $listOwnMembers = $hashClusters[$intOwnCluster]
                $dblA = 0.0
                if ($listOwnMembers.Count -gt 1) {
                    foreach ($intJ in $listOwnMembers) {
                        if ($intJ -eq $intI) {
                            continue
                        }
                        $dblA += [Math]::Sqrt((Get-SquaredEuclideanDistance -VectorA $arrVector -VectorB $VectorRows[$intJ].Vector))
                    }
                    $dblA /= ($listOwnMembers.Count - 1)
                }

                # b: minimum mean distance to any other cluster
                $dblB = [double]::PositiveInfinity
                foreach ($intK in $hashClusters.Keys) {
                    if ($intK -eq $intOwnCluster) {
                        continue
                    }
                    $listMembers = $hashClusters[$intK]
                    if ($listMembers.Count -eq 0) {
                        continue
                    }

                    $dblClusterDistance = 0.0
                    foreach ($intJ in $listMembers) {
                        $dblClusterDistance += [Math]::Sqrt((Get-SquaredEuclideanDistance -VectorA $arrVector -VectorB $VectorRows[$intJ].Vector))
                    }
                    $dblClusterDistance /= $listMembers.Count
                    if ($dblClusterDistance -lt $dblB) {
                        $dblB = $dblClusterDistance
                    }
                }

                $dblDenominator = [Math]::Max($dblA, $dblB)
                $dblSilhouette = 0.0
                if ($dblDenominator -gt 0) {
                    $dblSilhouette = ($dblB - $dblA) / $dblDenominator
                }
                $dblSumSilhouette += $dblSilhouette
            }

            Write-Verbose ("Approximate silhouette score: {0:F4}" -f ($dblSumSilhouette / $intSampleCount))

            $dblSumSilhouette / $intSampleCount
        } catch {
            Write-Debug ("Failed to compute silhouette score: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
