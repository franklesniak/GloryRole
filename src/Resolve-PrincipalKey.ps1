Set-StrictMode -Version Latest

function Resolve-PrincipalKey {
    # .SYNOPSIS
    # Resolves identity fields to a stable principal key and type.
    # .DESCRIPTION
    # Determines the canonical principal key from available identity fields
    # using the precedence: ObjectId > AppId > Caller. Returns a
    # PSCustomObject with Key and Type properties, or $null if no identity
    # can be resolved.
    # .PARAMETER ObjectId
    # The object identifier claim from Azure AD (for human users).
    # .PARAMETER AppId
    # The application identifier claim (for service principals).
    # .PARAMETER Caller
    # The raw caller field from the activity log record.
    # .EXAMPLE
    # $objPrincipal = Resolve-PrincipalKey -ObjectId 'abc-123' -AppId '' -Caller 'user@example.com'
    # # $objPrincipal.Key = 'abc-123'
    # # $objPrincipal.Type = 'User'
    #
    # # When ObjectId is present, it takes precedence and the type is 'User'.
    # .EXAMPLE
    # $objPrincipal = Resolve-PrincipalKey -ObjectId '' -AppId 'app-456' -Caller ''
    # # $objPrincipal.Key = 'app-456'
    # # $objPrincipal.Type = 'ServicePrincipal'
    #
    # # When ObjectId is absent but AppId is present, it is used with type
    # # 'ServicePrincipal'.
    # .EXAMPLE
    # $objPrincipal = Resolve-PrincipalKey -ObjectId '' -AppId '' -Caller ''
    # # $objPrincipal = $null
    #
    # # When all identity fields are empty, $null is returned.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] An object with the following properties:
    #   - Key  ([string]) The resolved principal identifier.
    #   - Type ([string]) One of: 'User', 'ServicePrincipal', or 'Unknown'.
    # Returns $null if no identity can be resolved (all inputs are empty or
    # whitespace-only).
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
    #   Position 0: ObjectId
    #   Position 1: AppId
    #   Position 2: Caller
    #
    # Version: 1.1.20260410.1

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [string]$ObjectId,
        [string]$AppId,
        [string]$Caller
    )

    process {
        if ($PSBoundParameters.ContainsKey('Verbose') -or $VerbosePreference -ne 'SilentlyContinue') {
            Write-Verbose (
                "Resolving principal key (ObjectIdPresent={0}, AppIdPresent={1}, CallerPresent={2})" -f
                (-not [string]::IsNullOrWhiteSpace($ObjectId)),
                (-not [string]::IsNullOrWhiteSpace($AppId)),
                (-not [string]::IsNullOrWhiteSpace($Caller))
            )
        }
        try {
            if (-not [string]::IsNullOrWhiteSpace($ObjectId)) {
                Write-Debug 'Resolved via ObjectId (User)'
                return [pscustomobject]@{
                    Key = $ObjectId
                    Type = 'User'
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($AppId)) {
                Write-Debug 'Resolved via AppId (ServicePrincipal)'
                return [pscustomobject]@{
                    Key = $AppId
                    Type = 'ServicePrincipal'
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($Caller)) {
                Write-Debug 'Resolved via Caller (Unknown)'
                return [pscustomobject]@{
                    Key = $Caller
                    Type = 'Unknown'
                }
            }
            Write-Debug 'No identity field resolved; returning $null'
            return $null
        } catch {
            Write-Debug ("Resolve-PrincipalKey failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
