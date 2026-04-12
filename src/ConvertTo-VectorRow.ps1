Set-StrictMode -Version Latest

function ConvertTo-VectorRow {
    # .SYNOPSIS
    # Converts principal-action counts into dense vector rows for
    # clustering.
    # .DESCRIPTION
    # Transforms PrincipalActionCount sparse triples into fixed-length
    # dense vectors using the provided feature index. Each principal
    # produces one vector row where the vector dimension equals the number
    # of features in the index.
    # .PARAMETER Counts
    # An array of PrincipalActionCount sparse triples.
    # .PARAMETER FeatureIndexObject
    # The feature index object from New-FeatureIndex containing
    # FeatureIndex (hashtable) and FeatureNames (array).
    # .EXAMPLE
    # $arrRows = @(ConvertTo-VectorRow -Counts $arrCounts -FeatureIndexObject $objIndex)
    # # $arrRows[0].PrincipalKey = 'user-abc'
    # # $arrRows[0].Vector = [double[]] (fixed-length array)
    # # $arrRows[0].TotalActions = 42.0
    # .EXAMPLE
    # $arrCounts = @(
    #     [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; Count = 7.0 }
    # )
    # $objIndex = New-FeatureIndex -PrincipalActionCounts $arrCounts
    # $arrRows = @(ConvertTo-VectorRow -Counts $arrCounts -FeatureIndexObject $objIndex)
    # # $arrRows.Count
    # # # Returns 1
    # # $arrRows[0].Vector.Length
    # # # Returns 1 (matches the single feature in the index)
    # # $arrRows[0].Vector[0]
    # # # Returns 7.0
    # # $arrRows[0].TotalActions
    # # # Returns 7.0
    #
    # # Demonstrates minimal valid input: a single principal with a single
    # # action count. The vector dimension matches the feature count (1),
    # # and the single count appears at the correct index.
    # .EXAMPLE
    # $arrCounts = @(
    #     [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; Count = 3.0 }
    #     [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'write'; Count = 2.0 }
    #     [pscustomobject]@{ PrincipalKey = 'user2'; Action = 'read'; Count = 1.0 }
    # )
    # $objIndex = New-FeatureIndex -PrincipalActionCounts $arrCounts
    # $arrRows = @(ConvertTo-VectorRow -Counts $arrCounts -FeatureIndexObject $objIndex)
    # $objUser2 = $arrRows | Where-Object { $_.PrincipalKey -eq 'user2' }
    # # $objUser2.Vector
    # # # Returns @(1.0, 0.0) — 'read' is at index 0 with count 1.0,
    # # # 'write' is at index 1 with count 0.0 (zero-filled).
    # # $objUser2.TotalActions
    # # # Returns 1.0
    #
    # # Demonstrates zero-fill behavior for missing actions. User2 has
    # # only the 'read' action, so the 'write' position is filled with
    # # zero in the output vector.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] Vector row objects with PrincipalKey, Vector, and
    # TotalActions properties.
    # .NOTES
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
    #   Position 0: Counts
    #   Position 1: FeatureIndexObject

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Counts,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$FeatureIndexObject
    )

    process {
        try {
            $hashFeatureIndex = $FeatureIndexObject.FeatureIndex
            $intDimension = $FeatureIndexObject.FeatureNames.Count

            Write-Verbose ("Building vector rows from {0} counts with {1} features" -f $Counts.Count, $intDimension)

            $hashVectorsByPrincipal = @{}
            $hashTotalByPrincipal = @{}

            foreach ($objRow in $Counts) {
                $strPrincipal = [string]$objRow.PrincipalKey
                $strAction = [string]$objRow.Action
                $dblCount = [double]$objRow.Count

                if (-not $hashVectorsByPrincipal.ContainsKey($strPrincipal)) {
                    $hashVectorsByPrincipal[$strPrincipal] = New-Object double[] $intDimension
                    $hashTotalByPrincipal[$strPrincipal] = 0.0
                }

                if ($hashFeatureIndex.ContainsKey($strAction)) {
                    $intIndex = [int]$hashFeatureIndex[$strAction]
                    $hashVectorsByPrincipal[$strPrincipal][$intIndex] += $dblCount
                    $hashTotalByPrincipal[$strPrincipal] += $dblCount
                }
            }

            Write-Verbose ("Generated vector rows for {0} principals" -f $hashVectorsByPrincipal.Count)

            foreach ($strPrincipal in ($hashVectorsByPrincipal.Keys | Sort-Object)) {
                [pscustomobject]@{
                    PrincipalKey = $strPrincipal
                    Vector = $hashVectorsByPrincipal[$strPrincipal]
                    TotalActions = [double]$hashTotalByPrincipal[$strPrincipal]
                }
            }
        } catch {
            Write-Debug ("Failed to build vector rows: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
