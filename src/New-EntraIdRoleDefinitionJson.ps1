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
    #
    # Before generating JSON, the function performs a defensive
    # validation pass on each resource action. If a
    # microsoft.directory/* action string appears to contain an
    # accidentally downcased camelCase segment (e.g.,
    # oauth2permissiongrants instead of oAuth2PermissionGrants), a
    # Write-Warning is emitted for each such action. This catches the
    # common mistake of piping Entra ID actions through a lowercase
    # normalizer intended only for Azure RBAC. JSON generation still
    # proceeds so that the caller can inspect the output, but the
    # resulting role definition will likely be rejected by the
    # Microsoft Graph API.
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
    # Version: 1.1.20260418.0

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
            # ---------------------------------------------------------------
            # Defensive validation: detect accidentally downcased camelCase
            # segments in microsoft.directory/* actions. These known
            # camelCase resource type segments contain uppercase letters
            # that MUST be preserved; the Microsoft Graph
            # unifiedRoleDefinition API rejects all-lowercase forms.
            #
            # Source: resource type segments extracted from the
            # ConvertTo-EntraIdResourceAction.ps1 mapping table. Review
            # and update this list when new Entra ID resource types are
            # added to the mapping table.
            # ---------------------------------------------------------------
            $arrKnownCamelCaseSegments = @(
                'oAuth2PermissionGrants'
                'servicePrincipals'
                'conditionalAccessPolicies'
                'roleAssignments'
                'roleDefinitions'
                'administrativeUnits'
                'accessReviews'
                'applicationPolicies'
                'applicationTemplates'
                'attributeSets'
                'authorizationPolicy'
                'certificateBasedDeviceAuthConfigurations'
                'connectorGroups'
                'crossTenantAccessPolicy'
                'customAuthenticationExtensions'
                'customSecurityAttributeDefinitions'
                'deletedItems'
                'deviceManagementPolicies'
                'deviceRegistrationPolicy'
                'deviceTemplates'
                'entitlementManagement'
                'externalUserProfiles'
                'groupSettings'
                'hybridAuthenticationPolicy'
                'identityProtection'
                'identityProviders'
                'lifecycleWorkflows'
                'loginOrganizationBranding'
                'multiTenantOrganization'
                'namedLocations'
                'passwordHashSync'
                'pendingExternalUserProfiles'
                'permissionGrantPolicies'
                'privilegedIdentityManagement'
                'roleEligibilityScheduleRequest'
                'scopedRoleMemberships'
                'servicePrincipalCreationPolicies'
                'tenantGovernance'
                'userCredentialPolicies'
                'verifiableCredentials'
                'b2cTrustFrameworkKeySet'
                'b2cTrustFrameworkPolicy'
                'inviteGuest'
            )

            foreach ($strAction in $ResourceActions) {
                if ($strAction -like 'microsoft.directory/*') {
                    foreach ($strSegment in $arrKnownCamelCaseSegments) {
                        $strLower = $strSegment.ToLowerInvariant()
                        if ($strSegment -cne $strLower -and
                            ($strAction -clike ('*/' + $strLower + '/*') -or
                            $strAction -clike ('*/' + $strLower))) {
                            Write-Warning ("Resource action '{0}' appears to contain an accidentally downcased segment '{1}' (expected '{2}'). Entra ID microsoft.directory/* actions MUST preserve camelCase. This role definition will likely be rejected by the Microsoft Graph API." -f $strAction, $strLower, $strSegment)
                        }
                    }
                }
            }

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
