Set-StrictMode -Version Latest

function ConvertTo-NormalizedVectorRow {
    # .SYNOPSIS
    # Applies Log1P and/or L2 normalization to vector rows in place.
    # .DESCRIPTION
    # Transforms the Vector property of each vector row using optional
    # Log1P (log(1 + x)) and L2 (unit length) normalization. Both are
    # enabled by default and represent the recommended normalization for
    # K-Means clustering on action count data.
    #
    # This function modifies the Vector property of the input objects in
    # place. Callers should be aware that the original objects are mutated
    # as a side effect. If the original vectors must be preserved, clone
    # the objects before calling this function.
    #
    # Each modified row object is streamed to the pipeline as it is
    # processed, consistent with modern PowerShell function design.
    # Callers should wrap the call in @(...) if they need an array (e.g.,
    # $arrResult = @(ConvertTo-NormalizedVectorRow -VectorRows $arrRows)).
    # This function does NOT throw on individual row errors; instead it
    # logs the error to the Debug stream, emits a warning, and continues
    # to the next row. Callers MUST check the output count if all rows
    # are expected to succeed.
    # .PARAMETER VectorRows
    # An array of vector row objects with a Vector property.
    # .PARAMETER Log1P
    # Apply Log1P transformation. Default is true.
    # .PARAMETER L2
    # Apply L2 normalization. Default is true.
    # .EXAMPLE
    # $objRow1 = [pscustomobject]@{ PrincipalKey = 'user1'; Vector = @(3.0, 4.0) }
    # $objRow2 = [pscustomobject]@{ PrincipalKey = 'user2'; Vector = @(0.0, 1.0) }
    # $arrResult = @(ConvertTo-NormalizedVectorRow -VectorRows @($objRow1, $objRow2))
    # # $arrResult.Count = 2
    # # $arrResult[0].Vector[0] ≈ 0.7168 (Log1P then L2-normalized)
    # # $arrResult[0].Vector[1] ≈ 0.6973
    # # Both Log1P and L2 normalization are applied by default. The
    # # result vectors have unit length (L2 norm = 1.0).
    # .EXAMPLE
    # $objRow = [pscustomobject]@{ PrincipalKey = 'user1'; Vector = @(0.0, 1.0, 9.0) }
    # $arrResult = @(ConvertTo-NormalizedVectorRow -VectorRows @($objRow) -L2 $false)
    # # $arrResult[0].Vector[0] = 0.0       (Log1P(0) = 0)
    # # $arrResult[0].Vector[1] ≈ 0.6931    (Log1P(1) = ln(2))
    # # $arrResult[0].Vector[2] ≈ 2.3026    (Log1P(9) = ln(10))
    # # Only Log1P transformation is applied. Each output element equals
    # # [Math]::Log(1 + x) for the corresponding input element.
    # .EXAMPLE
    # $objRow = [pscustomobject]@{ PrincipalKey = 'user1'; Vector = @(0.0, 0.0, 0.0) }
    # $arrResult = @(ConvertTo-NormalizedVectorRow -VectorRows @($objRow))
    # # $arrResult[0].Vector = @(0.0, 0.0, 0.0)
    # # A zero vector remains all zeros after normalization. L2
    # # normalization is gracefully skipped because the sum of squares
    # # is zero, avoiding division by zero.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] The same vector row objects with transformed
    # vectors.
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
    #   Position 0: VectorRows

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$VectorRows,

        [bool]$Log1P = $true,
        [bool]$L2 = $true
    )

    process {
        Write-Verbose ("Normalizing {0} vector row(s) (Log1P={1}, L2={2})" -f $VectorRows.Count, $Log1P, $L2)

        foreach ($objRow in $VectorRows) {
            try {
                $arrVector = $objRow.Vector

                if ($Log1P) {
                    $arrTransformed = New-Object double[] $arrVector.Length
                    for ($intIndex = 0; $intIndex -lt $arrVector.Length; $intIndex++) {
                        $arrTransformed[$intIndex] = [Math]::Log(1.0 + $arrVector[$intIndex])
                    }
                    $arrVector = $arrTransformed
                }

                if ($L2) {
                    $dblSumSquared = 0.0
                    for ($intIndex = 0; $intIndex -lt $arrVector.Length; $intIndex++) {
                        $dblSumSquared += ($arrVector[$intIndex] * $arrVector[$intIndex])
                    }

                    if ($dblSumSquared -gt 0.0) {
                        $dblNorm = [Math]::Sqrt($dblSumSquared)
                        $arrNormalized = New-Object double[] $arrVector.Length
                        for ($intIndex = 0; $intIndex -lt $arrVector.Length; $intIndex++) {
                            $arrNormalized[$intIndex] = $arrVector[$intIndex] / $dblNorm
                        }
                        $arrVector = $arrNormalized
                        Write-Debug ("Row vector length: {0}, L2 norm: {1}" -f $arrVector.Length, $dblNorm)
                    }
                }

                $objRow.Vector = $arrVector
                $objRow
            } catch {
                Write-Debug ("Failed to normalize vector row: {0}" -f $_)
                Write-Warning ("Skipping vector row due to error: {0}" -f $_)
                continue
            }
        }
    }
}
