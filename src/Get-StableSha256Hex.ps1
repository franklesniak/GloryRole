Set-StrictMode -Version Latest

function Get-StableSha256Hex {
    # .SYNOPSIS
    # Computes a stable SHA-256 hex hash of a salted input string.
    # .DESCRIPTION
    # Produces a deterministic, lowercase hexadecimal SHA-256 hash by
    # concatenating the salt, a pipe separator, and the input string. This
    # is used for identity anonymization in published datasets, avoiding
    # the non-deterministic behavior of .GetHashCode().
    # .PARAMETER InputString
    # The string value to hash.
    # .PARAMETER Salt
    # A salt value prepended to the input before hashing.
    # .EXAMPLE
    # $strHash = Get-StableSha256Hex -InputString 'user@example.com' -Salt 'demo-salt'
    # # Returns a 64-character lowercase hex string.
    # .EXAMPLE
    # $strHash1 = Get-StableSha256Hex -InputString 'alice' -Salt 'mySalt'
    # $strHash2 = Get-StableSha256Hex -InputString 'alice' -Salt 'mySalt'
    # $strHash1 -eq $strHash2
    # # Demonstrates deterministic behavior: calling the function twice with
    # # the same InputString and Salt always produces the same hash. The
    # # comparison returns $true.
    # .EXAMPLE
    # $strHashA = Get-StableSha256Hex -InputString 'bob' -Salt 'salt-one'
    # $strHashB = Get-StableSha256Hex -InputString 'bob' -Salt 'salt-two'
    # $strHashA -eq $strHashB
    # # Shows that different Salt values produce different hashes for the
    # # same InputString. The comparison returns $false.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [string] A 64-character lowercase hexadecimal SHA-256 hash.
    # .NOTES
    # Version: 1.1.20260410.0
    #
    # Supported PowerShell versions:
    #   - Windows PowerShell 5.1 (.NET Framework 4.6.2 or newer)
    #   - PowerShell 7.4.x, 7.5.x, and 7.6.x (Windows, macOS, and Linux)
    #
    # This function supports positional parameters:
    #   Position 0: InputString
    #   Position 1: Salt

    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$InputString,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Salt
    )

    process {
        $objSha256Hasher = $null
        try {
            if ($PSBoundParameters.ContainsKey('Verbose') -or $VerbosePreference -ne 'SilentlyContinue') {
                Write-Verbose ("Computing SHA-256 hash for input of length {0}." -f $InputString.Length)
            }
            $arrBytesToHash = [System.Text.Encoding]::UTF8.GetBytes($Salt + '|' + $InputString)
            $objSha256Hasher = [System.Security.Cryptography.SHA256]::Create()
            $arrHashedBytes = $objSha256Hasher.ComputeHash($arrBytesToHash)
            -join ($arrHashedBytes | ForEach-Object { $_.ToString('x2') })
        } catch {
            Write-Debug ("Get-StableSha256Hex failed: {0}" -f $(if ($_.Exception.Message) { $_.Exception.Message } else { $_.ToString() }))
            throw
        } finally {
            if ($null -ne $objSha256Hasher) {
                $objSha256Hasher.Dispose()
            }
        }
    }
}
