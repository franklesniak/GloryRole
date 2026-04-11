Set-StrictMode -Version Latest

function ConvertFrom-ClaimsJson {
    # .SYNOPSIS
    # Safely converts a claims value to a usable object.
    # .DESCRIPTION
    # Accepts a claims value that may be a JSON string, an object, or $null,
    # and returns a parsed object suitable for property access. Returns
    # $null if the input cannot be parsed.
    # .PARAMETER Claims
    # The raw claims value from an Azure activity log record.
    # .EXAMPLE
    # $objClaims = ConvertFrom-ClaimsJson -Claims '{"appid":"abc-123"}'
    # # $objClaims.appid = 'abc-123'
    # .EXAMPLE
    # $objClaims = ConvertFrom-ClaimsJson -Claims $null
    # # Returns: $null
    # .EXAMPLE
    # $objExisting = [pscustomobject]@{ appid = 'existing' }
    # $objResult = ConvertFrom-ClaimsJson -Claims $objExisting
    # # $objResult is the same instance as $objExisting (object passthrough)
    # .EXAMPLE
    # $objClaims = ConvertFrom-ClaimsJson -Claims 'not JSON at all'
    # # Returns: $null because the string does not start with '{'
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [object] When Claims is a JSON string, returns a [pscustomobject]
    # from ConvertFrom-Json. When Claims is already an object (e.g., a
    # hashtable or pscustomobject), returns it as-is. Returns $null when
    # Claims is $null or a non-JSON string.
    # .NOTES
    # Version: 1.0.20260410.0
    #
    # Supported PowerShell versions:
    # - Windows PowerShell 5.1 (with .NET Framework 4.6.2 or newer)
    # - PowerShell 7.4.x, 7.5.x, and 7.6.x
    #
    # Supported platforms:
    # - Windows (PowerShell 5.1 or 7.x)
    # - macOS and Linux (PowerShell 7.x only)
    #
    # This function supports positional parameters:
    #   Position 0: Claims

    [CmdletBinding()]
    [OutputType([object])]
    param (
        [object]$Claims
    )

    process {
        $boolVerbose = $PSBoundParameters.ContainsKey('Verbose') -or $VerbosePreference -ne 'SilentlyContinue'
        if ($null -eq $Claims) {
            if ($boolVerbose) {
                Write-Verbose "Claims input is `$null; returning `$null."
            }
            return $null
        }

        if ($Claims -is [string]) {
            if ($boolVerbose) {
                Write-Verbose ("Claims input is a string ({0} characters); attempting JSON parse." -f $Claims.Length)
            }
            $strTrimmed = $Claims.Trim()
            if ($strTrimmed.StartsWith('{')) {
                try {
                    return ($strTrimmed | ConvertFrom-Json)
                } catch {
                    Write-Debug ("Failed to parse claims JSON: {0}" -f $_.Exception.Message)
                    return $null
                }
            }
            return $null
        }

        if ($boolVerbose) {
            Write-Verbose ("Claims input is an object of type [{0}]; returning as-is." -f $Claims.GetType().Name)
        }
        return $Claims
    }
}
