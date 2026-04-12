Set-StrictMode -Version Latest

function Import-PrincipalActionCountFromCsv {
    # .SYNOPSIS
    # Imports principal-action count sparse triples from a local CSV file.
    # .DESCRIPTION
    # Reads a CSV file containing PrincipalKey, Action, and Count columns
    # and returns PrincipalActionCount sparse triples. Actions are
    # normalized during import. This is the recommended ingestion mode for
    # deterministic demos and CI testing.
    # .PARAMETER Path
    # The path to the CSV file containing sparse triples.
    # .EXAMPLE
    # $arrCounts = @(Import-PrincipalActionCountFromCsv -Path (Join-Path -Path $HOME -ChildPath 'data/principal_action_counts.csv'))
    # # $arrCounts[0].PrincipalKey  # e.g., 'user@contoso.com'
    # # $arrCounts[0].Action        # e.g., 'microsoft.compute/virtualmachines/read'
    # # $arrCounts[0].Count         # e.g., 42
    # # Each output object is a sparse triple with PrincipalKey, Action,
    # # and Count properties.
    # .EXAMPLE
    # $arrCounts = @(Import-PrincipalActionCountFromCsv -Path '.\nonexistent.csv')
    # # Throws "CSV file not found: .\nonexistent.csv" because the file does not exist.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] PrincipalActionCount sparse triples with properties:
    #   - PrincipalKey ([string]): The identity key for the principal.
    #   - Action ([string]): The normalized action string.
    #   - Count ([double]): The numeric count for this principal-action pair.
    # .NOTES
    # The CSV file MUST have columns: PrincipalKey, Action, Count.
    # Requires ConvertTo-NormalizedAction to be loaded.
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
    #   Position 0: Path
    #
    # Version: 1.1.20260410.0

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    process {
        Write-Verbose ("Importing principal-action counts from: {0}" -f $Path)

        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw ("CSV file not found: {0}" -f $Path)
        }

        try {
            $arrRows = Import-Csv -LiteralPath $Path -ErrorAction Stop

            Write-Verbose ("{0} rows loaded from CSV." -f @($arrRows).Count)

            foreach ($objRow in $arrRows) {
                $strAction = ConvertTo-NormalizedAction -Action ([string]$objRow.Action)
                if ([string]::IsNullOrWhiteSpace($strAction)) {
                    Write-Debug "Skipping row: action is empty or whitespace after normalization."
                    continue
                }

                [pscustomobject]@{
                    PrincipalKey = [string]$objRow.PrincipalKey
                    Action = $strAction
                    Count = [double]$objRow.Count
                }
            }
        } catch {
            $strErrorMessage = $null
            if ($null -ne $_ -and $null -ne $_.Exception -and
                -not [string]::IsNullOrEmpty($_.Exception.Message)) {
                $strErrorMessage = $_.Exception.Message
            } else {
                $strErrorMessage = ($_ | Out-String)
            }
            Write-Debug ("Import-PrincipalActionCountFromCsv failed: {0}" -f $strErrorMessage)
            throw
        }
    }
}
