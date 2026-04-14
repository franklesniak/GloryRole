Set-StrictMode -Version Latest

function Get-EntraIdRoleDisplayName {
    # .SYNOPSIS
    # Generates a descriptive display name for an Entra ID custom role
    # based on its resource actions.
    # .DESCRIPTION
    # Analyzes an array of microsoft.directory/* resource action strings
    # and generates a meaningful human-readable display name that
    # describes the role's purpose. The function parses the resource
    # type from each action (e.g., users, groups, applications),
    # identifies the dominant resource types, and constructs a name
    # such as "User & Group Manager" or "Application Administrator".
    #
    # When a prefix is provided, the generated name is appended to the
    # prefix with a dash separator and the ClusterId is appended as a
    # trailing suffix to guarantee uniqueness across clusters (Entra ID
    # requires role definition displayName values to be unique within
    # a tenant). When no meaningful name can be generated (e.g., empty
    # or unrecognized actions), a fallback name using the cluster ID is
    # returned.
    # .PARAMETER ResourceActions
    # An array of microsoft.directory/* resource action strings that
    # define the role's permissions.
    # .PARAMETER ClusterId
    # The numeric cluster ID used as a fallback suffix when a
    # descriptive name cannot be generated.
    # .PARAMETER Prefix
    # Optional prefix prepended to the generated name. Default is
    # 'GloryRole'.
    # .EXAMPLE
    # $strName = Get-EntraIdRoleDisplayName -ResourceActions @('microsoft.directory/users/create', 'microsoft.directory/users/basic/update', 'microsoft.directory/users/password/update') -ClusterId 0
    # # Returns: 'GloryRole-User Manager-0'
    # # The actions are all user-related, so the generated name
    # # reflects user management. The trailing '-0' is the ClusterId
    # # suffix, which keeps the display name unique across clusters.
    # .EXAMPLE
    # $strName = Get-EntraIdRoleDisplayName -ResourceActions @('microsoft.directory/groups/members/update', 'microsoft.directory/users/basic/update') -ClusterId 1
    # # Returns: 'GloryRole-User & Group Manager-1'
    # # Multiple resource types produce a combined name with the
    # # dominant types joined by ampersands. The trailing '-1'
    # # is the ClusterId suffix.
    # .EXAMPLE
    # $strName = Get-EntraIdRoleDisplayName -ResourceActions @() -ClusterId 5
    # # Returns: 'GloryRole-EntraCluster-5'
    # # Empty actions produce a generic fallback name.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [string] A descriptive display name for the Entra ID custom role.
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
    #   Position 0: ResourceActions
    #   Position 1: ClusterId
    #
    # Version: 1.0.20260414.1

    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$ResourceActions,

        [Parameter(Mandatory = $true)]
        [int]$ClusterId,

        [string]$Prefix = 'GloryRole'
    )

    process {
        try {
            if ($null -eq $ResourceActions -or $ResourceActions.Count -eq 0) {
                return ("{0}-EntraCluster-{1}" -f $Prefix, $ClusterId)
            }

            # Map from resource type token (extracted from
            # microsoft.directory/{resourceType}/...) to a
            # human-friendly label and a weight for sorting.
            $hashResourceLabels = @{
                'users' = 'User'
                'groups' = 'Group'
                'applications' = 'Application'
                'servicePrincipals' = 'Service Principal'
                'devices' = 'Device'
                'conditionalAccessPolicies' = 'Conditional Access'
                'roleAssignments' = 'Role Assignment'
                'roleDefinitions' = 'Role Definition'
                'roleEligibilityScheduleRequest' = 'Role Eligibility'
                'oAuth2PermissionGrants' = 'Permission Grant'
                'administrativeUnits' = 'Administrative Unit'
                'namedLocations' = 'Named Location'
                'policies' = 'Policy'
                'domains' = 'Domain'
                'organization' = 'Organization'
                'contacts' = 'Contact'
                'groupSettings' = 'Group Settings'
                'applicationPolicies' = 'Application Policy'
                'connectorGroups' = 'App Proxy'
                'connectors' = 'App Proxy'
                'customAuthenticationExtensions' = 'Auth Extension'
                'crossTenantAccessPolicy' = 'Cross-Tenant Access'
                'identityProtection' = 'Identity Protection'
                'entitlementManagement' = 'Entitlement'
                'lifecycleWorkflows' = 'Lifecycle Workflow'
                'accessReviews' = 'Access Review'
                'privilegedIdentityManagement' = 'PIM'
                'loginOrganizationBranding' = 'Branding'
                'scopedRoleMemberships' = 'Scoped Role'
                'multiTenantOrganization' = 'Multi-Tenant Org'
                'authorizationPolicy' = 'Authorization Policy'
                'partners' = 'Partner'
                'deletedItems' = 'Deleted Items'
                'verifiableCredentials' = 'Verifiable Credential'
                'b2cTrustFrameworkPolicy' = 'B2C Policy'
                'b2cTrustFrameworkKeySet' = 'B2C Key Set'
                'identityProviders' = 'Identity Provider'
                'externalUserProfiles' = 'External User'
                'pendingExternalUserProfiles' = 'External User'
                'userCredentialPolicies' = 'Credential Policy'
                'customSecurityAttributeDefinitions' = 'Security Attribute'
                'attributeSets' = 'Attribute Set'
                'hybridAuthenticationPolicy' = 'Hybrid Auth'
                'passwordHashSync' = 'Password Sync'
                'deviceManagementPolicies' = 'Device Policy'
                'deviceRegistrationPolicy' = 'Device Registration'
                'servicePrincipalCreationPolicies' = 'SP Creation Policy'
                'permissionGrantPolicies' = 'Permission Policy'
                'certificateBasedDeviceAuthConfigurations' = 'IoT Device'
                'deviceTemplates' = 'IoT Device'
                'tenantGovernance' = 'Tenant Governance'
                'groupsAssignableToRoles' = 'Role-Assignable Group'
                'directoryRoles' = 'Directory Role'
                'applicationTemplates' = 'App Template'
            }

            # Priority order for display name (lower = appears first).
            $hashResourcePriority = @{
                'User' = 1
                'Group' = 2
                'Application' = 3
                'Service Principal' = 4
                'Device' = 5
                'Role Assignment' = 6
                'Role Definition' = 7
                'Role Eligibility' = 8
                'Conditional Access' = 9
                'Policy' = 10
                'Permission Grant' = 11
                'Administrative Unit' = 12
                'Named Location' = 13
                'Domain' = 14
                'Organization' = 15
            }

            # Extract resource types from action strings and count them.
            $hashResourceCounts = @{}
            foreach ($strAction in $ResourceActions) {
                # Pattern: microsoft.directory/{resourceType}/{...}
                if ($strAction -match '^microsoft\.directory/([^/]+)/') {
                    $strResourceType = $Matches[1]

                    # Normalize dotted subtypes to their parent segment
                    # (e.g., groups.unified -> groups, groups.security ->
                    # groups). The URL path is split on '/' first, so the
                    # segment `deletedItems` in
                    # microsoft.directory/deletedItems/users/... stays as
                    # `deletedItems` and is not affected by this rule.
                    if ($strResourceType -match '\.') {
                        $strResourceType = $strResourceType.Split('.')[0]
                    }

                    # Map to label
                    $strLabel = $null
                    if ($hashResourceLabels.ContainsKey($strResourceType)) {
                        $strLabel = $hashResourceLabels[$strResourceType]
                    }

                    if ($null -ne $strLabel) {
                        if ($hashResourceCounts.ContainsKey($strLabel)) {
                            $hashResourceCounts[$strLabel] = $hashResourceCounts[$strLabel] + 1
                        } else {
                            $hashResourceCounts[$strLabel] = 1
                        }
                    }
                }
            }

            if ($hashResourceCounts.Count -eq 0) {
                return ("{0}-EntraCluster-{1}" -f $Prefix, $ClusterId)
            }

            # Sort by priority (known types first), then by count
            # descending, then alphabetically.
            $hashSortByPriority = @{
                Expression = {
                    if ($hashResourcePriority.ContainsKey($_)) {
                        $hashResourcePriority[$_]
                    } else {
                        100
                    }
                }
            }
            $hashSortByCount = @{
                Expression = { $hashResourceCounts[$_] }
                Descending = $true
            }
            $hashSortByName = @{
                Expression = { $_ }
            }
            $arrSortedLabels = @(
                $hashResourceCounts.Keys | Sort-Object -Property $hashSortByPriority, $hashSortByCount, $hashSortByName
            )

            # Determine suffix based on action types (create, delete,
            # update patterns). Analyze all actions for the verb.
            $boolHasCreate = $false
            $boolHasDelete = $false
            foreach ($strAction in $ResourceActions) {
                $strLower = $strAction.ToLowerInvariant()
                if ($strLower -match '/create$' -or $strLower -match '/allTasks$') {
                    $boolHasCreate = $true
                }
                if ($strLower -match '/delete$' -or $strLower -match '/allTasks$') {
                    $boolHasDelete = $true
                }
            }

            # Choose role suffix based on scope of permissions.
            $strSuffix = 'Manager'
            if ($boolHasCreate -and $boolHasDelete) {
                $strSuffix = 'Administrator'
            }

            # Limit to top 3 resource types for readability.
            $intMaxLabels = 3
            if ($arrSortedLabels.Count -gt $intMaxLabels) {
                $arrSortedLabels = $arrSortedLabels[0..($intMaxLabels - 1)]
            }

            $strResourceName = $arrSortedLabels -join ' & '

            # Append ClusterId to guarantee each generated name is
            # unique per cluster. Entra ID requires role definition
            # displayName values to be unique within a tenant, and
            # two clusters can otherwise produce identical
            # descriptive names (e.g., two distinct user-management
            # clusters both collapsing to "User Manager"). The
            # suffix mirrors the fallback path style
            # ("{Prefix}-EntraCluster-{ClusterId}").
            return ("{0}-{1} {2}-{3}" -f $Prefix, $strResourceName, $strSuffix, $ClusterId)
        } catch {
            Write-Debug ("Get-EntraIdRoleDisplayName failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
