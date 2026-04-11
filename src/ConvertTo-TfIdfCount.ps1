Set-StrictMode -Version Latest

function ConvertTo-TfIdfCount {
    # .SYNOPSIS
    # Applies TF-IDF weighting to principal-action counts.
    # .DESCRIPTION
    # Transforms raw principal-action counts using Term Frequency-Inverse
    # Document Frequency weighting. TF is the raw count, and IDF uses
    # smoothed log: log((1 + N) / (1 + df)) + 1, where N is the total
    # number of principals and df is the number of principals who performed
    # that action. This is an optional advanced weighting step.
    #
    # TF-IDF weighting reduces the influence of actions performed by nearly
    # every principal (common actions like read or list) and emphasizes
    # actions that are distinctive to individual principals, making the
    # resulting vectors more useful for clustering or role-mining analysis.
    # .PARAMETER Counts
    # An array of PrincipalActionCount sparse triples.
    # .EXAMPLE
    # $arrCounts = @(
    #     [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'read'; Count = 3.0 }
    # )
    # $arrWeighted = @(ConvertTo-TfIdfCount -Counts $arrCounts)
    # $arrWeighted[0].Count
    # # # Expected output: 3
    # # With a single principal, N = 1 and df = 1, so
    # # IDF = log((1 + 1) / (1 + 1)) + 1 = log(1) + 1 = 1.0.
    # # The output Count equals the raw input Count (3.0 * 1.0 = 3.0).
    #
    # .EXAMPLE
    # $arrCounts = @(
    #     [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'read'; Count = 2.0 }
    #     [pscustomobject]@{ PrincipalKey = 'user-a'; Action = 'delete'; Count = 1.0 }
    #     [pscustomobject]@{ PrincipalKey = 'user-b'; Action = 'read'; Count = 5.0 }
    # )
    # $arrWeighted = @(ConvertTo-TfIdfCount -Counts $arrCounts)
    # # With two principals (N = 2):
    # # 'read' is performed by both principals (df = 2), so
    # #   IDF = log((1 + 2) / (1 + 2)) + 1 = log(1) + 1 = 1.0
    # #   user-a read Count = 2.0 * 1.0 = 2.0
    # #   user-b read Count = 5.0 * 1.0 = 5.0
    # # 'delete' is performed by only user-a (df = 1), so
    # #   IDF = log((1 + 2) / (1 + 1)) + 1 = log(1.5) + 1 ≈ 1.4055
    # #   user-a delete Count = 1.0 * 1.4055 ≈ 1.4055
    # # TF-IDF down-weights common actions (read) and up-weights
    # # distinctive actions (delete).
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] PrincipalActionCount sparse triples with TF-IDF
    # weighted counts.
    # Returns no objects when the input contains no principals (empty input).
    # .NOTES
    # Version: 1.2.20260410.1
    #
    # This function supports positional parameters:
    #   Position 0: Counts
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

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Counts
    )

    process {
        try {
            Write-Verbose -Message ("Computing TF-IDF weighted counts for {0} input triples..." -f $Counts.Count)

            if ($Counts.Count -eq 0) {
                Write-Warning -Message "No count triples provided. Output will be empty."
            }

            #region Document-Frequency Computation
            $hashDocumentFrequency = @{}
            $hashPrincipals = @{}

            foreach ($objRow in $Counts) {
                $strPrincipal = [string]$objRow.PrincipalKey
                $strAction = [string]$objRow.Action

                if ([string]::IsNullOrEmpty($strPrincipal) -or [string]::IsNullOrEmpty($strAction)) {
                    Write-Warning -Message "Skipping count triple with missing or non-numeric PrincipalKey, Action, or Count property."
                    Write-Debug -Message "Malformed count triple skipped: missing or empty PrincipalKey/Action."
                    continue
                }

                $dblCount = $null
                try {
                    $dblCount = [double]$objRow.Count
                } catch {
                    Write-Debug -Message ("Count value '{0}' is not numeric." -f $objRow.Count)
                }

                if ($null -eq $dblCount) {
                    Write-Warning -Message "Skipping count triple with missing or non-numeric PrincipalKey, Action, or Count property."
                    Write-Debug -Message "Malformed count triple skipped: non-numeric or missing Count value."
                    continue
                }

                $hashPrincipals[$strPrincipal] = $true
                if (-not $hashDocumentFrequency.ContainsKey($strAction)) {
                    $hashDocumentFrequency[$strAction] = @{}
                }
                $hashDocumentFrequency[$strAction][$strPrincipal] = $true
            }

            Write-Debug -Message ("Document frequency pass complete: {0} unique principals, {1} unique actions." -f $hashPrincipals.Count, $hashDocumentFrequency.Count)
            #endregion Document-Frequency Computation

            $dblN = [double]$hashPrincipals.Count
            if ($dblN -le 0) {
                return
            }

            #region TF-IDF Emission
            $intEmittedTripleCount = 0
            foreach ($objRow in $Counts) {
                $strPrincipal = [string]$objRow.PrincipalKey
                $strAction = [string]$objRow.Action

                if ([string]::IsNullOrEmpty($strPrincipal) -or [string]::IsNullOrEmpty($strAction)) {
                    continue
                }

                $dblCount = $null
                try {
                    $dblCount = [double]$objRow.Count
                } catch {
                    Write-Debug -Message ("Count value '{0}' is not numeric." -f $objRow.Count)
                }

                if ($null -eq $dblCount) {
                    continue
                }

                $dblTf = $dblCount
                $dblDf = [double]$hashDocumentFrequency[$strAction].Count

                $dblIdf = [Math]::Log((1.0 + $dblN) / (1.0 + $dblDf)) + 1.0

                [pscustomobject]@{
                    PrincipalKey = $objRow.PrincipalKey
                    Action = $objRow.Action
                    Count = $dblTf * $dblIdf
                }
                $intEmittedTripleCount++
            }

            Write-Verbose -Message ("Emitted {0} TF-IDF weighted count triples." -f $intEmittedTripleCount)
            #endregion TF-IDF Emission
        } catch {
            Write-Debug -Message ("Failed to compute TF-IDF weighted counts: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
