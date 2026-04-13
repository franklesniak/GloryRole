Set-StrictMode -Version Latest

function Resolve-LocalizableStringValue {
    # .SYNOPSIS
    # Normalizes a "localizable string" field from Azure PowerShell output.
    # .DESCRIPTION
    # Azure PowerShell historically returned many string-like fields (for
    # example Status, Category, and OperationName on activity log records)
    # as PSObject values exposing .Value and .LocalizedValue properties.
    # Starting with Az.Monitor 7.0.0, those same fields are returned as
    # plain [string] values, which causes $field.Value reads to fail under
    # Set-StrictMode -Version Latest.
    #
    # This helper accepts any of those shapes and returns a single
    # [string] result suitable for downstream string processing. Inputs of
    # any other shape are treated as unresolvable and produce $null.
    # .PARAMETER InputObject
    # The field value to normalize. May be $null, a [string], or a
    # PSObject exposing a .Value or .LocalizedValue property.
    # .EXAMPLE
    # $strResult = Resolve-LocalizableStringValue -InputObject 'Succeeded'
    # # $strResult = 'Succeeded'
    #
    # # Plain strings (the Az.Monitor 7+ shape) pass through unchanged.
    # .EXAMPLE
    # $objLegacy = [pscustomobject]@{ Value = 'Succeeded'; LocalizedValue = 'Succeeded' }
    # $strResult = Resolve-LocalizableStringValue -InputObject $objLegacy
    # # $strResult = 'Succeeded'
    #
    # # Legacy Az.Monitor PSLocalizedString objects are reduced to their
    # # .Value, which holds the non-localized canonical value.
    # .EXAMPLE
    # $strResult = Resolve-LocalizableStringValue -InputObject $null
    # # $strResult = $null
    #
    # # A $null input returns $null rather than an empty string, so callers
    # # can distinguish "absent" from "present but empty".
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [string] The resolved text value. Returns $null when the input is
    # $null or is an object that exposes neither .Value nor .LocalizedValue.
    # .NOTES
    # Supported PowerShell versions:
    #   - Windows PowerShell 5.1 (.NET Framework 4.6.2+)
    #   - PowerShell 7.4.x
    #   - PowerShell 7.5.x
    #   - PowerShell 7.6.x
    # Supported operating systems:
    #   - Windows (Windows PowerShell 5.1 and PowerShell 7.x)
    #   - macOS (PowerShell 7.x only)
    #   - Linux (PowerShell 7.x only)
    #
    # This function supports positional parameters:
    #   Position 0: InputObject
    #
    # Version: 1.0.20260413.0

    [CmdletBinding()]
    [OutputType([string])]
    param (
        [object]$InputObject
    )

    process {
        try {
            if ($null -eq $InputObject) {
                return $null
            }

            if ($InputObject -is [string]) {
                return [string]$InputObject
            }

            # Guard PSObject access so non-PSObject primitive/value types
            # fall through to the $null return rather than throwing under
            # Set-StrictMode -Version Latest.
            if ($null -ne $InputObject.PSObject -and $null -ne $InputObject.PSObject.Properties) {
                if ($InputObject.PSObject.Properties['Value']) {
                    $objInner = $InputObject.Value
                    if ($null -ne $objInner) {
                        return [string]$objInner
                    }
                }
                if ($InputObject.PSObject.Properties['LocalizedValue']) {
                    $objInner = $InputObject.LocalizedValue
                    if ($null -ne $objInner) {
                        return [string]$objInner
                    }
                }
            }

            return $null
        } catch {
            Write-Debug ("Resolve-LocalizableStringValue failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
