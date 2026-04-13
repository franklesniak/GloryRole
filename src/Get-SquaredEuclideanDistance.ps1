Set-StrictMode -Version Latest

function Get-SquaredEuclideanDistance {
    # .SYNOPSIS
    # Computes the squared Euclidean distance between two vectors.
    # .DESCRIPTION
    # Calculates the sum of squared differences between corresponding
    # elements of two equal-length double arrays. Used as the distance
    # metric for K-Means clustering. Returns the squared distance (not the
    # square root) for performance.
    # .PARAMETER VectorA
    # The first vector, represented as a double array ([double[]]). Must be the
    # same length as VectorB.
    # .PARAMETER VectorB
    # The second vector, represented as a double array ([double[]]). Must be the
    # same length as VectorA.
    # .EXAMPLE
    # $dblDistance = Get-SquaredEuclideanDistance -VectorA @(1.0, 2.0) -VectorB @(4.0, 6.0)
    # # Returns: 25.0 (= (4-1)^2 + (6-2)^2)
    # .EXAMPLE
    # $dblDistance = Get-SquaredEuclideanDistance -VectorA @(3.0, 4.0) -VectorB @(3.0, 4.0)
    # # Returns: 0.0
    # # Identical vectors have zero distance between them.
    # .EXAMPLE
    # $dblDistance = Get-SquaredEuclideanDistance -VectorA @(0.0) -VectorB @(5.0)
    # # Returns: 25.0 (= (5-0)^2)
    # # The function works with single-element (1-dimensional) vectors.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [double] The squared Euclidean distance.
    # .NOTES
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
    #   Position 0: VectorA
    #   Position 1: VectorB
    #
    # Version: 1.1.20260410.0

    [CmdletBinding()]
    [OutputType([double])]
    param (
        [Parameter(Mandatory = $true)]
        [double[]]$VectorA,

        [Parameter(Mandatory = $true)]
        [double[]]$VectorB
    )

    process {
        try {
            if ($VectorA.Length -ne $VectorB.Length) {
                throw ("VectorA length ({0}) does not match VectorB length ({1}). Both vectors must be the same length." -f $VectorA.Length, $VectorB.Length)
            }
            $boolVerbose = $PSBoundParameters.ContainsKey('Verbose') -or $VerbosePreference -ne 'SilentlyContinue'
            if ($boolVerbose) {
                Write-Verbose ("Computing squared Euclidean distance for {0}-element vectors" -f $VectorA.Length)
            }
            $dblSum = 0.0
            for ($intIndex = 0; $intIndex -lt $VectorA.Length; $intIndex++) {
                $dblDifference = $VectorA[$intIndex] - $VectorB[$intIndex]
                $dblSum += ($dblDifference * $dblDifference)
            }
            if ($boolVerbose) {
                Write-Verbose ("Squared Euclidean distance = {0}" -f $dblSum)
            }
            $dblSum
        } catch {
            Write-Debug ("Get-SquaredEuclideanDistance failed: {0}" -f $(if ($_.Exception.Message) { $_.Exception.Message } else { $_.ToString() }))
            throw
        }
    }
}
