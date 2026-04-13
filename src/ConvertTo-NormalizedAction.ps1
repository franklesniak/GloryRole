Set-StrictMode -Version Latest

function ConvertTo-NormalizedAction {
    # .SYNOPSIS
    # Normalizes an Azure action string to lowercase with whitespace trimmed.
    # .DESCRIPTION
    # Takes a raw Azure action string (e.g., from Authorization.Action) and
    # returns it in a canonical lowercase, trimmed form suitable for
    # consistent comparison and aggregation. Returns $null if the input is
    # null or whitespace-only.
    # .PARAMETER Action
    # The raw action string to normalize.
    # .EXAMPLE
    # $strNormalized = ConvertTo-NormalizedAction -Action '  Microsoft.Compute/virtualMachines/Read  '
    # # Returns: 'microsoft.compute/virtualmachines/read'
    # # Leading and trailing whitespace is stripped and all characters are
    # # converted to lowercase using culture-invariant rules, ensuring
    # # consistent comparison and aggregation regardless of the original casing.
    # .EXAMPLE
    # $strNormalized = ConvertTo-NormalizedAction -Action $null
    # # Returns: $null
    # # $null is returned when the input is null or whitespace-only, allowing
    # # callers to detect and skip non-actionable input.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [string] The normalized action string, or $null if input is blank.
    # .NOTES
    # Version: 1.2.20260410.0
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
    #   Position 0: Action

    [CmdletBinding()]
    [OutputType([string])]
    param (
        [string]$Action
    )

    process {
        try {
            if ($PSBoundParameters.ContainsKey('Verbose') -or $VerbosePreference -ne 'SilentlyContinue') {
                Write-Verbose ("Normalizing action: '{0}'" -f $Action)
            }
            if ([string]::IsNullOrWhiteSpace($Action)) {
                return $null
            }
            $Action.Trim().ToLowerInvariant()
        } catch {
            Write-Debug ("Failed to normalize action: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
