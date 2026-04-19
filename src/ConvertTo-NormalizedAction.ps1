Set-StrictMode -Version Latest

function ConvertTo-NormalizedAction {
    # .SYNOPSIS
    # Normalizes an Azure RBAC action string to lowercase with whitespace
    # trimmed.
    # .DESCRIPTION
    # Takes a raw Azure RBAC action string (e.g., from
    # Authorization.Action) and returns it in a canonical lowercase,
    # trimmed form suitable for consistent comparison and aggregation.
    # Returns $null if the input is null or whitespace-only.
    #
    # WARNING - Azure RBAC only: This function applies culture-invariant
    # lowercasing and MUST NOT be used for Entra ID
    # microsoft.directory/* actions. Entra ID resource action strings
    # contain camelCase segments (e.g., oAuth2PermissionGrants,
    # servicePrincipals, conditionalAccessPolicies) that the Microsoft
    # Graph unifiedRoleDefinition API requires to be preserved exactly.
    # Lowercasing these segments produces invalid role definitions that
    # the API will reject. For Entra ID paths, use trim-only
    # normalization (see Import-PrincipalActionCountFromCsv with
    # -RoleSchema EntraId).
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
    # WARNING: This function is intended for Azure RBAC actions only.
    # Do NOT call this function on Entra ID microsoft.directory/* action
    # strings. Entra ID actions contain camelCase segments (such as
    # oAuth2PermissionGrants and servicePrincipals) that must be
    # preserved verbatim. Lowercasing them produces invalid role
    # definitions rejected by the Microsoft Graph API.
    #
    # Version: 1.3.20260418.0
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
