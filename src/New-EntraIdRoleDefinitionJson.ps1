Set-StrictMode -Version Latest

function New-EntraIdRoleDefinitionJson {
    # .SYNOPSIS
    # Generates an Entra ID custom role definition JSON string.
    # .DESCRIPTION
    # Creates a valid Entra ID custom role definition JSON document in
    # the unifiedRoleDefinition format from the provided role name,
    # description, and resource actions list. The output can be used
    # with Microsoft Graph API to create custom Entra ID roles via
    # New-MgRoleManagementDirectoryRoleDefinition.
    #
    # The JSON follows the Microsoft Graph unifiedRoleDefinition schema
    # with rolePermissions containing allowedResourceActions in the
    # microsoft.directory/* namespace.
    # .PARAMETER RoleName
    # The display name for the custom Entra ID role.
    # .PARAMETER Description
    # A description of the custom Entra ID role.
    # .PARAMETER ResourceActions
    # An array of allowed resource actions in the microsoft.directory/*
    # namespace.
    # .PARAMETER IsEnabled
    # Whether the role is enabled. Default is $true.
    # .EXAMPLE
    # $strJson = New-EntraIdRoleDefinitionJson -RoleName 'Group Manager' -Description 'Manages group membership' -ResourceActions @('microsoft.directory/groups/members/update')
    # # Returns a JSON string defining an Entra ID custom role named
    # # 'Group Manager' with a single group membership update action.
    # .EXAMPLE
    # $strJson = New-EntraIdRoleDefinitionJson -RoleName 'User Admin Lite' -Description 'Limited user management' -ResourceActions @('microsoft.directory/users/basic/update', 'microsoft.directory/users/password/update') -IsEnabled $false
    # # Returns a JSON string with two user management actions and the
    # # role disabled. The resulting JSON can be used with
    # # New-MgRoleManagementDirectoryRoleDefinition.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [string] A JSON string representing the Entra ID custom role
    # definition in the unifiedRoleDefinition format.
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
    #   Position 2: ResourceActions
    #
    # Version: 1.0.20260415.0

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'The "New-" verb constructs an in-memory JSON string; no external or system state is modified, so ShouldProcess support is not applicable.')]
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RoleName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ResourceActions,

        [bool]$IsEnabled = $true
    )

    process {
        Write-Verbose ("Generating Entra ID role definition JSON for role: {0}" -f $RoleName)

        try {
            $hashRole = [ordered]@{
                displayName = $RoleName
                description = $Description
                isEnabled = $IsEnabled
                rolePermissions = @(
                    [ordered]@{
                        allowedResourceActions = $ResourceActions
                        condition = $null
                    }
                )
            }

            $hashRole | ConvertTo-Json -Depth 8 -ErrorAction Stop
        } catch {
            Write-Debug ("Failed to generate Entra ID role definition JSON for role '{0}': {1}" -f $RoleName, $_.Exception.Message)
            throw
        }
    }
}
