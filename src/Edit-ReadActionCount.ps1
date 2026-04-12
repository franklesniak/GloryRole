Set-StrictMode -Version Latest

function Edit-ReadActionCount {
    # .SYNOPSIS
    # Applies a read-dominance handling mode to principal-action counts.
    # .DESCRIPTION
    # Handles actions ending in '/read' using one of three modes:
    # - Keep: No modification; keeps read-only personas visible.
    # - DownWeight: Multiplies read action counts by the ReadWeight factor
    #   (default 0.25). Good default that preserves signal but reduces
    #   dominance.
    # - Exclude: Removes all read actions entirely.
    # This MUST be applied before feature universe creation.
    # .PARAMETER Counts
    # An array of PrincipalActionCount sparse triples.
    # .PARAMETER Mode
    # The read handling mode: Keep, DownWeight, or Exclude.
    # Default is DownWeight.
    # .PARAMETER ReadWeight
    # The weight factor for DownWeight mode. Default is 0.25.
    # .EXAMPLE
    # $arrAdjusted = @(Edit-ReadActionCount -Counts $arrCounts -Mode 'DownWeight' -ReadWeight 0.25)
    # # Applies DownWeight mode with a 0.25 weight factor. Read actions
    # # have their Count multiplied by 0.25; non-read actions are
    # # unchanged.
    # .EXAMPLE
    # $arrResult = @(Edit-ReadActionCount -Counts $arrCounts -Mode 'Keep')
    # # Returns all input triples unchanged. Read actions retain their
    # # original Count values.
    # .EXAMPLE
    # $arrResult = @(Edit-ReadActionCount -Counts $arrCounts -Mode 'Exclude')
    # # Returns only non-read triples. Any action ending in '/read' is
    # # removed from the output.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject]
    # Streamed PrincipalActionCount sparse triples with read handling
    # applied. Each object has the following properties:
    #
    # - PrincipalKey ([string]): The principal key from the input triple.
    # - Action ([string]): The action string from the input triple.
    # - Count ([double]): The count, potentially adjusted by the weight
    #   factor.
    #
    # The function may emit zero objects if all input actions match the
    # exclusion criteria (e.g., Mode is 'Exclude' and every input action
    # ends in '/read').
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
    # Version: 2.0.20260410.2

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Counts,

        [ValidateSet('Keep', 'DownWeight', 'Exclude')]
        [string]$Mode = 'DownWeight',

        [double]$ReadWeight = 0.25
    )

    process {
        Write-Verbose ("Applying read-action handling: Mode={0}, ReadWeight={1}" -f $Mode, $ReadWeight)
        try {
            Write-Debug ("Processing {0} input row(s) in '{1}' mode." -f $Counts.Count, $Mode)
            switch ($Mode) {
                'Keep' {
                    Write-Debug "Executing 'Keep' branch: returning all rows unchanged."
                    foreach ($objRow in $Counts) {
                        $objRow
                    }
                }

                'Exclude' {
                    Write-Debug "Executing 'Exclude' branch: filtering out */read actions."
                    foreach ($objRow in $Counts) {
                        if ([string]$objRow.Action -notlike '*/read') {
                            $objRow
                        }
                    }
                }

                'DownWeight' {
                    Write-Debug ("Executing 'DownWeight' branch: applying weight factor {0}." -f $ReadWeight)
                    foreach ($objRow in $Counts) {
                        $dblWeight = 1.0
                        if ([string]$objRow.Action -like '*/read') {
                            $dblWeight = $ReadWeight
                        }
                        [pscustomobject]@{
                            PrincipalKey = $objRow.PrincipalKey
                            Action = $objRow.Action
                            Count = [double]$objRow.Count * $dblWeight
                        }
                    }
                }
            }
        } catch {
            Write-Debug ("Edit-ReadActionCount failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
