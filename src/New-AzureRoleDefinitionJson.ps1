Set-StrictMode -Version Latest

function New-AzureRoleDefinitionJson {
    # .SYNOPSIS
    # Generates an Azure custom role definition JSON string.
    # .DESCRIPTION
    # Creates a valid Azure custom role definition JSON document from the
    # provided role name, description, actions list, and assignable scopes.
    # The output can be saved to a file and used with
    # New-AzRoleDefinition -InputFile.
    # .PARAMETER RoleName
    # The display name for the custom role.
    # .PARAMETER Description
    # A description of the custom role.
    # .PARAMETER Actions
    # An array of allowed management-plane actions.
    # .PARAMETER AssignableScopes
    # An array of scopes where this role can be assigned.
    # .EXAMPLE
    # $strJson = New-AzureRoleDefinitionJson -RoleName 'Storage Reader' -Description 'Read-only access to storage' -Actions @('Microsoft.Storage/*/read') -AssignableScopes @('/subscriptions/sub-1')
    # # Returns a JSON string defining a custom role named 'Storage Reader'
    # # with a single storage read action scoped to one subscription.
    # .EXAMPLE
    # $strJson = New-AzureRoleDefinitionJson -RoleName 'Network Contributor' -Description 'Manage virtual networks' -Actions @('Microsoft.Network/virtualNetworks/read', 'Microsoft.Network/virtualNetworks/write', 'Microsoft.Network/virtualNetworks/delete') -AssignableScopes @('/subscriptions/sub-1', '/subscriptions/sub-2')
    # # Returns a JSON string with three network actions and two assignable
    # # scopes. The resulting JSON can be saved to a file and used with
    # # New-AzRoleDefinition -InputFile.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [string] A JSON string representing the Azure role definition.
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
    #   Position 0: RoleName
    #   Position 1: Description
    #   Position 2: Actions
    #   Position 3: AssignableScopes
    #
    # Version: 1.1.20260422.0

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'The "New-" verb constructs an in-memory JSON string; no external or system state is modified, so ShouldProcess support is not applicable.')]
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RoleName,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string[]]$Actions,

        [Parameter(Mandatory = $true)]
        [string[]]$AssignableScopes
    )

    process {
        Write-Verbose ("Generating role definition JSON for role: {0}" -f $RoleName)

        try {
            $hashtableRole = [ordered]@{
                Name = $RoleName
                IsCustom = $true
                Description = $Description
                Actions = $Actions
                NotActions = @()
                DataActions = @()
                NotDataActions = @()
                AssignableScopes = $AssignableScopes
            }

            $hashtableRole | ConvertTo-Json -Depth 8 -ErrorAction Stop
        } catch {
            Write-Debug ("Failed to generate role definition JSON for role '{0}': {1}" -f $RoleName, $_.Exception.Message)
            throw
        }
    }
}
