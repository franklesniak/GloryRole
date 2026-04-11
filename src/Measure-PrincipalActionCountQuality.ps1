Set-StrictMode -Version Latest

function Measure-PrincipalActionCountQuality {
    # .SYNOPSIS
    # Computes quality metrics for a set of principal-action counts.
    # .DESCRIPTION
    # Analyzes a collection of PrincipalActionCount sparse triples and
    # returns a quality report including distinct principal count, distinct
    # action count, non-zero entry count, matrix density, and the top 10
    # actions and principals by frequency.
    # .PARAMETER Counts
    # An array of PrincipalActionCount sparse triples.
    # .EXAMPLE
    # $objQuality = Measure-PrincipalActionCountQuality -Counts $arrCounts
    # # $objQuality.Principals = 42
    # # $objQuality.Actions = 128
    # # $objQuality.Density = 0.03
    # .EXAMPLE
    # $arrSmallSet = @(
    #     [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; Count = 5 }
    #     [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'write'; Count = 3 }
    #     [pscustomobject]@{ PrincipalKey = 'user2'; Action = 'read'; Count = 7 }
    # )
    # $objQuality = Measure-PrincipalActionCountQuality -Counts $arrSmallSet
    # # $objQuality.NonZeroEntries = 3
    # # $objQuality.TopActions[0].Name = 'read'
    # # $objQuality.TopActions[0].Count = 2
    # # $objQuality.TopPrincipals[0].Name = 'user1'
    # # $objQuality.TopPrincipals[0].Count = 2
    # # Demonstrates constructing a minimal data set inline and inspecting
    # # the TopActions and TopPrincipals properties of the returned object.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] A quality metrics report object with the following
    # properties:
    #
    # - Principals ([int]): Distinct principal count.
    # - Actions ([int]): Distinct action count.
    # - NonZeroEntries ([int]): Total number of sparse triples.
    # - Density ([double]): Ratio of non-zero entries to the full matrix
    #   (Principals x Actions); zero when either dimension is zero.
    # - TopActions ([object[]]): Up to 10 most frequent actions with Name
    #   and Count properties.
    # - TopPrincipals ([object[]]): Up to 10 most frequent principals with
    #   Name and Count properties.
    #
    # This function does not return $null because the Counts parameter is
    # mandatory.
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
    #
    # Version: 1.1.20260410.0

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Counts
    )

    process {
        try {
            Write-Verbose ("Processing {0} input row(s)." -f $Counts.Count)

            $arrPrincipalKeys = @($Counts | Select-Object -ExpandProperty PrincipalKey | Sort-Object -Unique)
            $arrActionNames = @($Counts | Select-Object -ExpandProperty Action | Sort-Object -Unique)
            $intPrincipalCount = $arrPrincipalKeys.Count
            $intActionCount = $arrActionNames.Count
            $intNonZeroEntries = $Counts.Count

            $dblDensity = 0.0
            if ($intPrincipalCount -gt 0 -and $intActionCount -gt 0) {
                $dblDensity = $intNonZeroEntries / ([double]$intPrincipalCount * [double]$intActionCount)
            }

            Write-Debug ("Principals: {0}, Actions: {1}, NonZeroEntries: {2}, Density: {3}" -f $intPrincipalCount, $intActionCount, $intNonZeroEntries, $dblDensity)

            $arrTopActions = @($Counts |
                Group-Object -Property Action |
                Sort-Object -Property Count -Descending |
                Select-Object -First 10 -Property Name, Count)

            $arrTopPrincipals = @($Counts |
                Group-Object -Property PrincipalKey |
                Sort-Object -Property Count -Descending |
                Select-Object -First 10 -Property Name, Count)

            [pscustomobject]@{
                Principals = $intPrincipalCount
                Actions = $intActionCount
                NonZeroEntries = $intNonZeroEntries
                Density = $dblDensity
                TopActions = $arrTopActions
                TopPrincipals = $arrTopPrincipals
            }
        } catch {
            Write-Debug ("Measure-PrincipalActionCountQuality failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
