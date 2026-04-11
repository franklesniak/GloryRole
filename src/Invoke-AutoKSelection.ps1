Set-StrictMode -Version Latest

function Invoke-AutoKSelection {
    # .SYNOPSIS
    # Automatically selects the optimal K for K-Means clustering using a
    # weighted composite index across multiple metrics.
    # .DESCRIPTION
    # Evaluates K-Means clustering for each K value from MinK to MaxK,
    # computing WCSS (SSE), approximate silhouette score, Davies-Bouldin
    # index, and Calinski-Harabasz index. Derives WCSS first and second
    # derivatives using central differences. Each metric is converted to
    # an ordinal rank (1 = best). The final composite score is a weighted
    # average of ranks, and the K with the lowest composite rank wins.
    #
    # When MaxK is 0 (the default), it is auto-calculated using
    # Ceiling(Sqrt(N) * 1.2), aligning with the AutoCategorizerPS
    # heuristic. The auto-calculated value is still clamped to N.
    #
    # When the maximum silhouette score across all candidates is below
    # SilhouetteBiasThreshold (default 0.4), a cluster-count rank biased
    # toward Ceiling(Sqrt(N)) is also included with its own weight.
    #
    # This methodology is aligned with the composite scoring approach
    # from AutoCategorizerPS.
    # .PARAMETER VectorRows
    # An array of vector row objects with PrincipalKey and Vector
    # properties.
    # .PARAMETER MinK
    # Minimum K to evaluate. Default is 2.
    # .PARAMETER MaxK
    # Maximum K to evaluate. When set to 0 or a negative value (the
    # default), MaxK is auto-calculated as Ceiling(Sqrt(N) * 1.2).
    # When an explicit positive value is provided, it is used directly
    # and clamped to N.
    # .PARAMETER Seed
    # Random seed for deterministic K-Means. Default is 42.
    # .PARAMETER SilhouetteSampleSize
    # Sample size for approximate silhouette computation. Default is 200.
    # .PARAMETER WeightWCSS
    # Weighting factor for raw WCSS rank. Default is 3.
    # .PARAMETER WeightWCSSSecondDerivative
    # Weighting factor for WCSS second derivative (elbow) rank. Default
    # is 40.
    # .PARAMETER WeightSilhouette
    # Weighting factor for silhouette score rank. Default is 18.
    # .PARAMETER WeightDaviesBouldin
    # Weighting factor for Davies-Bouldin index rank. Default is 13.
    # .PARAMETER WeightCalinskiHarabasz
    # Weighting factor for Calinski-Harabasz index rank. Default is 12.
    # .PARAMETER WeightClusterCount
    # Weighting factor for cluster count bias rank (only active when max
    # silhouette < SilhouetteBiasThreshold). Default is 14.
    # .PARAMETER SilhouetteBiasThreshold
    # When the maximum silhouette across all K values is below this
    # threshold, the cluster-count bias is activated. Default is 0.4.
    # .EXAMPLE
    # $objAutoK = Invoke-AutoKSelection -VectorRows $arrRows -MinK 2 -MaxK 10
    # # $objAutoK.RecommendedK contains the selected K
    # # $objAutoK.BestModel contains the K-Means result for that K
    # # $objAutoK.Candidates lists all evaluated K values with metrics
    # .EXAMPLE
    # $objAutoK = Invoke-AutoKSelection -VectorRows $arrRows
    # # MaxK defaults to 0 (auto-calculated as Ceiling(Sqrt(N)*1.2)).
    # # $objAutoK.RecommendedK contains the selected K.
    # # $objAutoK.Candidates lists all evaluated K values with metrics.
    # .EXAMPLE
    # $objAutoK = Invoke-AutoKSelection -VectorRows $arrRows -MinK 3 -MaxK 8 -Seed 123
    # # Evaluates K=3 through K=8 with a fixed seed for reproducible results.
    # # $objAutoK.RecommendedK contains the selected K.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] An Auto-K result object with the following properties:
    #   - RecommendedK ([int]): The K value with the lowest composite rank.
    #   - BestModel ([pscustomobject]): The K-Means result for the recommended
    #     K, containing K, Assignments, Centroids, and SSE.
    #   - Candidates ([object[]]): All evaluated K values sorted by K in
    #     ascending order, each element a [pscustomobject] with SSE,
    #     Silhouette, DaviesBouldin, CalinskiHarabasz, WCSSSecondDeriv,
    #     and rank properties.
    # .NOTES
    # Requires Invoke-KMeansClustering, Get-ApproximateSilhouetteScore,
    # Get-DaviesBouldinIndex, and Get-CalinskiHarabaszIndex to be loaded.
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
    #
    # Version: 2.1.20260410.0

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$VectorRows,

        [int]$MinK = 2,
        [int]$MaxK = 0,
        [int]$Seed = 42,
        [int]$SilhouetteSampleSize = 200,

        [double]$WeightWCSS = 3,
        [double]$WeightWCSSSecondDerivative = 40,
        [double]$WeightSilhouette = 18,
        [double]$WeightDaviesBouldin = 13,
        [double]$WeightCalinskiHarabasz = 12,
        [double]$WeightClusterCount = 14,
        [double]$SilhouetteBiasThreshold = 0.4
    )

    process {
        Write-Verbose ("Invoke-AutoKSelection: starting evaluation with N={0}, MinK={1}, MaxK={2}." -f $VectorRows.Count, $MinK, $MaxK)

        # Auto-calculate MaxK when sentinel value (0 or negative) is used
        $intN = $VectorRows.Count
        if ($MaxK -le 0) {
            $MaxK = [int][Math]::Ceiling([Math]::Sqrt($intN) * 1.2)
            Write-Verbose ("Auto-calculated MaxK={0} from N={1} using Ceiling(Sqrt(N)*1.2)." -f $MaxK, $intN)
        }

        # Clamp MaxK to N
        if ($MaxK -gt $intN) {
            $MaxK = $intN
        }
        if ($MinK -gt $MaxK) {
            throw ("MinK ({0}) cannot exceed MaxK ({1}) after clamping to N ({2})." -f $MinK, $MaxK, $intN)
        }

        #region Phase 1: Evaluate Each K
        $listStats = New-Object System.Collections.Generic.List[pscustomobject]

        for ($intKValue = $MinK; $intKValue -le $MaxK; $intKValue++) {
            try {
                Write-Verbose ("Evaluating K={0}..." -f $intKValue)

                $objKmResult = Invoke-KMeansClustering -VectorRows $VectorRows -K $intKValue -Seed $Seed -ErrorAction Stop

                $dblSilhouette = Get-ApproximateSilhouetteScore `
                    -VectorRows $VectorRows `
                    -KMeansResult $objKmResult `
                    -SampleSize $SilhouetteSampleSize `
                    -Seed $Seed `
                    -ErrorAction Stop

                $dblDaviesBouldin = Get-DaviesBouldinIndex `
                    -VectorRows $VectorRows `
                    -KMeansResult $objKmResult `
                    -ErrorAction Stop

                $dblCalinskiHarabasz = Get-CalinskiHarabaszIndex `
                    -VectorRows $VectorRows `
                    -KMeansResult $objKmResult `
                    -ErrorAction Stop

                [void]($listStats.Add([pscustomobject]@{
                    K = $intKValue
                    SSE = [double]$objKmResult.SSE
                    Silhouette = [double]$dblSilhouette
                    DaviesBouldin = [double]$dblDaviesBouldin
                    CalinskiHarabasz = [double]$dblCalinskiHarabasz
                    WCSSFirstDeriv = $null
                    WCSSSecondDeriv = $null
                    Model = $objKmResult
                }))
            } catch {
                Write-Debug ("Invoke-AutoKSelection: K={0} evaluation failed: {1}" -f $intKValue, $(if ($_.Exception.Message) { $_.Exception.Message } else { $_.ToString() }))
                throw
            }
        }

        $intCandidateCount = $listStats.Count
        #endregion Phase 1: Evaluate Each K

        #region Phase 2: Compute WCSS Derivatives
        $arrWcss = New-Object double[] $intCandidateCount
        for ($intIdx = 0; $intIdx -lt $intCandidateCount; $intIdx++) {
            $arrWcss[$intIdx] = $listStats[$intIdx].SSE
        }

        # First derivative
        $arrFirstDeriv = New-Object 'object[]' $intCandidateCount
        if ($intCandidateCount -ge 2) {
            # Forward difference at start
            $arrFirstDeriv[0] = [double]($arrWcss[1] - $arrWcss[0])
            # Backward difference at end
            $intLast = $intCandidateCount - 1
            $arrFirstDeriv[$intLast] = [double]($arrWcss[$intLast] - $arrWcss[$intLast - 1])
            # Central differences for interior
            for ($intIdx = 1; $intIdx -lt $intLast; $intIdx++) {
                $arrFirstDeriv[$intIdx] = [double](($arrWcss[$intIdx + 1] - $arrWcss[$intIdx - 1]) / 2.0)
            }
        }

        # Second derivative
        $arrSecondDeriv = New-Object 'object[]' $intCandidateCount
        if ($intCandidateCount -ge 3) {
            # Endpoints get null (not meaningful for elbow detection)
            $arrSecondDeriv[0] = $null
            $arrSecondDeriv[$intCandidateCount - 1] = $null
            # Central differences for interior
            for ($intIdx = 1; $intIdx -lt ($intCandidateCount - 1); $intIdx++) {
                $dblPrev = [double]$arrFirstDeriv[$intIdx - 1]
                $dblNext = [double]$arrFirstDeriv[$intIdx + 1]
                $arrSecondDeriv[$intIdx] = [double](($dblNext - $dblPrev) / 2.0)
            }
        }

        # Store derivatives back
        for ($intIdx = 0; $intIdx -lt $intCandidateCount; $intIdx++) {
            $listStats[$intIdx].WCSSFirstDeriv = $arrFirstDeriv[$intIdx]
            $listStats[$intIdx].WCSSSecondDeriv = $arrSecondDeriv[$intIdx]
        }
        #endregion Phase 2: Compute WCSS Derivatives

        #region Phase 3: Rank Metrics

        # WCSS rank: lowest SSE = rank 1
        $arrSortedByWcss = @($listStats | Sort-Object -Property SSE)
        for ($intRank = 0; $intRank -lt $intCandidateCount; $intRank++) {
            $arrSortedByWcss[$intRank] | Add-Member -NotePropertyName 'WCSSRank' -NotePropertyValue ($intRank + 1) -Force
        }

        # WCSS 2nd derivative rank: highest value = rank 1 (elbow)
        # Null values get worst rank
        $arrWithSecondDeriv = @($listStats | Where-Object { $null -ne $_.WCSSSecondDeriv })
        $arrWithoutSecondDeriv = @($listStats | Where-Object { $null -eq $_.WCSSSecondDeriv })
        $arrSortedBySecondDeriv = @($arrWithSecondDeriv | Sort-Object -Property WCSSSecondDeriv -Descending)
        $intRankCounter = 1
        foreach ($objStat in $arrSortedBySecondDeriv) {
            $objStat | Add-Member -NotePropertyName 'WCSSSecondDerivRank' -NotePropertyValue $intRankCounter -Force
            $intRankCounter++
        }
        foreach ($objStat in $arrWithoutSecondDeriv) {
            $objStat | Add-Member -NotePropertyName 'WCSSSecondDerivRank' -NotePropertyValue $intCandidateCount -Force
        }

        # Silhouette rank: highest = rank 1
        $arrSortedBySil = @($listStats | Sort-Object -Property Silhouette -Descending)
        for ($intRank = 0; $intRank -lt $intCandidateCount; $intRank++) {
            $arrSortedBySil[$intRank] | Add-Member -NotePropertyName 'SilhouetteRank' -NotePropertyValue ($intRank + 1) -Force
        }

        # Davies-Bouldin rank: lowest = rank 1
        $arrSortedByDb = @($listStats | Sort-Object -Property DaviesBouldin)
        for ($intRank = 0; $intRank -lt $intCandidateCount; $intRank++) {
            $arrSortedByDb[$intRank] | Add-Member -NotePropertyName 'DaviesBouldinRank' -NotePropertyValue ($intRank + 1) -Force
        }

        # Calinski-Harabasz rank: highest = rank 1
        $arrSortedByCh = @($listStats | Sort-Object -Property CalinskiHarabasz -Descending)
        for ($intRank = 0; $intRank -lt $intCandidateCount; $intRank++) {
            $arrSortedByCh[$intRank] | Add-Member -NotePropertyName 'CalinskiHarabaszRank' -NotePropertyValue ($intRank + 1) -Force
        }
        #endregion Phase 3: Rank Metrics

        #region Phase 4: Detect Low-Silhouette Bias Condition
        $dblMaxSilhouette = ($listStats | Measure-Object -Property Silhouette -Maximum).Maximum
        $boolUseBias = ($dblMaxSilhouette -lt $SilhouetteBiasThreshold)

        if ($boolUseBias) {
            Write-Verbose ("Max silhouette ({0:F4}) < {1:F2}: activating cluster-count bias." -f $dblMaxSilhouette, $SilhouetteBiasThreshold)

            $intIdealK = [int][Math]::Ceiling([Math]::Sqrt($intN))

            # Find the index in our candidates closest to the ideal K
            $intIdealIndex = 0
            $intMinDiff = [int]::MaxValue
            for ($intIdx = 0; $intIdx -lt $intCandidateCount; $intIdx++) {
                $intDiff = [Math]::Abs($listStats[$intIdx].K - $intIdealK)
                if ($intDiff -lt $intMinDiff) {
                    $intMinDiff = $intDiff
                    $intIdealIndex = $intIdx
                }
            }

            # Assign ranks using asymmetric spiral: ideal = rank 1, then
            # alternating below (3 steps) and above (1 step)
            $arrCountRanks = New-Object int[] $intCandidateCount
            for ($intIdx = 0; $intIdx -lt $intCandidateCount; $intIdx++) {
                $arrCountRanks[$intIdx] = $intCandidateCount  # default worst
            }

            $arrCountRanks[$intIdealIndex] = 1
            $intCurrentRank = 2
            $intBelow = $intIdealIndex - 1
            $intAbove = $intIdealIndex + 1

            while ($intBelow -ge 0 -or $intAbove -lt $intCandidateCount) {
                # 3 steps below (prefer fewer clusters)
                for ($intStep = 0; $intStep -lt 3; $intStep++) {
                    if ($intBelow -ge 0) {
                        $arrCountRanks[$intBelow] = $intCurrentRank
                        $intCurrentRank++
                        $intBelow--
                    }
                }
                # 1 step above
                if ($intAbove -lt $intCandidateCount) {
                    $arrCountRanks[$intAbove] = $intCurrentRank
                    $intCurrentRank++
                    $intAbove++
                }
            }

            for ($intIdx = 0; $intIdx -lt $intCandidateCount; $intIdx++) {
                $listStats[$intIdx] | Add-Member -NotePropertyName 'ClusterCountRank' -NotePropertyValue $arrCountRanks[$intIdx] -Force
            }
        }
        #endregion Phase 4: Detect Low-Silhouette Bias Condition

        #region Phase 5: Compute Composite Rank
        foreach ($objStat in $listStats) {
            $dblWeightedSum = 0.0
            $dblWeightSum = 0.0

            # WCSS
            $dblWeightedSum += $WeightWCSS * $objStat.WCSSRank
            $dblWeightSum += $WeightWCSS

            # WCSS 2nd derivative (skip if null source value)
            if ($null -ne $objStat.WCSSSecondDeriv) {
                $dblWeightedSum += $WeightWCSSSecondDerivative * $objStat.WCSSSecondDerivRank
                $dblWeightSum += $WeightWCSSSecondDerivative
            }

            # Silhouette
            $dblWeightedSum += $WeightSilhouette * $objStat.SilhouetteRank
            $dblWeightSum += $WeightSilhouette

            # Davies-Bouldin
            $dblWeightedSum += $WeightDaviesBouldin * $objStat.DaviesBouldinRank
            $dblWeightSum += $WeightDaviesBouldin

            # Calinski-Harabasz
            $dblWeightedSum += $WeightCalinskiHarabasz * $objStat.CalinskiHarabaszRank
            $dblWeightSum += $WeightCalinskiHarabasz

            # Cluster count bias (conditional)
            if ($boolUseBias) {
                $dblWeightedSum += $WeightClusterCount * $objStat.ClusterCountRank
                $dblWeightSum += $WeightClusterCount
            }

            $dblComposite = 0.0
            if ($dblWeightSum -gt 0) {
                $dblComposite = $dblWeightedSum / $dblWeightSum
            }

            $objStat | Add-Member -NotePropertyName 'CompositeRank' -NotePropertyValue ([double]$dblComposite) -Force
        }
        #endregion Phase 5: Compute Composite Rank

        #region Phase 6: Select Best K
        $objBest = $listStats | Sort-Object -Property CompositeRank | Select-Object -First 1

        Write-Verbose ("Selected K={0} with composite rank {1:F4}" -f $objBest.K, $objBest.CompositeRank)

        $arrCandidates = @($listStats |
            Sort-Object -Property K |
            Select-Object -Property K, SSE, Silhouette, DaviesBouldin, CalinskiHarabasz,
                WCSSSecondDeriv, WCSSRank, WCSSSecondDerivRank, SilhouetteRank,
                DaviesBouldinRank, CalinskiHarabaszRank, CompositeRank)

        [pscustomobject]@{
            RecommendedK = $objBest.K
            BestModel = $objBest.Model
            Candidates = $arrCandidates
        }
        #endregion Phase 6: Select Best K
    }
}
