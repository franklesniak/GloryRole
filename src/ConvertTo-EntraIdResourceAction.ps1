Set-StrictMode -Version Latest

# Script-scope cache for the Entra ID activity -> resource-action
# mapping. Initialized lazily on the first call to
# ConvertTo-EntraIdResourceAction. Per-record callers (such as
# ConvertFrom-EntraIdAuditRecord, which may be invoked thousands of
# times per pipeline run) therefore avoid rebuilding the 150+ entry
# hashtable on every invocation.
$script:hashEntraIdActivityMap = $null


function ConvertTo-EntraIdResourceAction {
    # .SYNOPSIS
    # Maps an Entra ID audit activity display name and category to a
    # microsoft.directory/* resource action string.
    # .DESCRIPTION
    # Converts an Entra ID directory audit activity display name into the
    # corresponding Microsoft Graph resource action permission string
    # (microsoft.directory/* namespace). Uses a static mapping table of
    # known administrative activities that correspond to real assignable
    # Entra ID custom role permissions.
    #
    # Unmapped activities (self-service events, informational audit
    # entries, and other non-administrative operations) return $null
    # so they are excluded from role mining output. Only activities
    # with explicit entries in the mapping table produce an action
    # string, ensuring that the output contains only permissions that
    # can be assigned in Entra ID custom role definitions
    # (unifiedRoleDefinition allowedResourceActions arrays).
    # .PARAMETER ActivityDisplayName
    # The activity display name from the directory audit record. This
    # is the **sole** lookup key for the mapping table; the match is
    # performed on a trimmed, invariant-lowercase form of this value.
    # .PARAMETER Category
    # The category from the directory audit record (e.g.,
    # 'GroupManagement', 'UserManagement', 'RoleManagement'). This
    # parameter is **informational only**: it is not used to select
    # the mapped resource action. It is included in the verbose
    # diagnostic output for unmapped activities so operators can see
    # the originating category context when adding new mappings, and
    # it is accepted so that per-record callers such as
    # ConvertFrom-EntraIdAuditRecord can forward it without losing
    # the record's category field. Future versions of this function
    # may incorporate Category into the lookup key if collisions
    # between categories emerge in the audit-log corpus.
    # .EXAMPLE
    # $strAction = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Add member to group' -Category 'GroupManagement'
    # # Returns: 'microsoft.directory/groups/members/update'
    # # The activity is found in the static mapping table and the
    # # corresponding resource action is returned.
    # .EXAMPLE
    # $strAction = ConvertTo-EntraIdResourceAction -ActivityDisplayName 'Self-service password reset flow activity progress' -Category 'UserManagement'
    # # Returns: $null
    # # Self-service and informational activities are not in the
    # # mapping table and return $null because they are not real
    # # assignable Entra ID custom role permissions.
    # .EXAMPLE
    # $strAction = ConvertTo-EntraIdResourceAction -ActivityDisplayName '' -Category ''
    # # Returns: $null
    # # Returns $null when the activity display name is null or empty.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [string] A microsoft.directory/* resource action string, or $null
    # if the activity display name is null or whitespace-only, or if
    # the activity is not a known administrative action.
    # .NOTES
    # The static mapping table covers common Entra ID administrative
    # audit activities. New mappings can be added to the
    # $hashActivityMap hashtable as Entra ID evolves.
    #
    # Activities not in the mapping table return $null rather than a
    # generated fallback string. This ensures that only real
    # assignable permissions appear in role mining output.
    #
    # Supported on Windows PowerShell 5.1 (.NET Framework 4.6.2+) and
    # PowerShell 7.4.x / 7.5.x / 7.6.x (Windows, macOS, Linux).
    #
    # This function supports positional parameters:
    #   Position 0: ActivityDisplayName
    #   Position 1: Category
    #
    # Version: 1.2.20260415.0

    [CmdletBinding()]
    [OutputType([string])]
    param (
        [string]$ActivityDisplayName,
        [string]$Category
    )

    process {
        try {
            if ([string]::IsNullOrWhiteSpace($ActivityDisplayName)) {
                return $null
            }

            $boolVerbose = $PSBoundParameters.ContainsKey('Verbose') -or $VerbosePreference -ne 'SilentlyContinue'

            # Static mapping from common Entra ID audit activity display
            # names to microsoft.directory/* resource action strings.
            # Keys are lowercase activity display names for
            # case-insensitive lookup. Comprehensive coverage of all
            # administrative audit activities that correspond to real
            # assignable Entra ID custom role permissions
            # (unifiedRoleDefinition allowedResourceActions).
            #
            # Build the mapping once and cache it in script scope so
            # that subsequent calls reuse the same hashtable instance.
            if ($null -ne $script:hashEntraIdActivityMap) {
                $hashActivityMap = $script:hashEntraIdActivityMap
            } else {
                $hashActivityMap = @{
                    #region Group management
                    'add member to group' = 'microsoft.directory/groups/members/update'
                    'remove member from group' = 'microsoft.directory/groups/members/update'
                    'add owner to group' = 'microsoft.directory/groups/owners/update'
                    'remove owner from group' = 'microsoft.directory/groups/owners/update'
                    'add group' = 'microsoft.directory/groups/create'
                    'delete group' = 'microsoft.directory/groups/delete'
                    'update group' = 'microsoft.directory/groups/basic/update'
                    'set group license' = 'microsoft.directory/groups/assignLicense'
                    'restore group' = 'microsoft.directory/groups/restore'
                    'hard delete group' = 'microsoft.directory/groups/delete'
                    'update dynamic membership rule on group' = 'microsoft.directory/groups/dynamicMembershipRule/update'
                    'set group classification' = 'microsoft.directory/groups/classification/update'
                    'set group type' = 'microsoft.directory/groups/groupType/update'
                    'set group visibility' = 'microsoft.directory/groups/visibility/update'
                    'update group settings' = 'microsoft.directory/groups/settings/update'
                    'assign label to group' = 'microsoft.directory/groups/assignedLabels/update'
                    'reprocess group license assignment' = 'microsoft.directory/groups/reprocessLicenseAssignment'
                    'set group on-premises write back' = 'microsoft.directory/groups/onPremWriteBack/update'
                    #endregion Group management

                    #region User management
                    'add user' = 'microsoft.directory/users/create'
                    'delete user' = 'microsoft.directory/users/delete'
                    'update user' = 'microsoft.directory/users/basic/update'
                    'reset user password' = 'microsoft.directory/users/password/update'
                    'change user password' = 'microsoft.directory/users/password/update'
                    'set force change user password' = 'microsoft.directory/users/password/update'
                    'restore user' = 'microsoft.directory/users/restore'
                    'hard delete user' = 'microsoft.directory/users/delete'
                    'update user principal name' = 'microsoft.directory/users/userPrincipalName/update'
                    'disable account' = 'microsoft.directory/users/disable'
                    'enable account' = 'microsoft.directory/users/enable'
                    'set user manager' = 'microsoft.directory/users/manager/update'
                    'remove user manager' = 'microsoft.directory/users/manager/update'
                    'invite external user' = 'microsoft.directory/users/inviteGuest'
                    'change user license' = 'microsoft.directory/users/assignLicense'
                    'update password profile' = 'microsoft.directory/users/password/update'
                    'update user photo' = 'microsoft.directory/users/photo/update'
                    'set usage location' = 'microsoft.directory/users/usageLocation/update'
                    'update usage location' = 'microsoft.directory/users/usageLocation/update'
                    'invalidate all refresh tokens for user' = 'microsoft.directory/users/invalidateAllRefreshTokens'
                    'revoke user sessions' = 'microsoft.directory/users/invalidateAllRefreshTokens'
                    'convert external user to internal member user' = 'microsoft.directory/users/convertExternalToInternalMemberUser'
                    'reprocess user license assignment' = 'microsoft.directory/users/reprocessLicenseAssignment'
                    'update user sponsors' = 'microsoft.directory/users/sponsors/update'
                    'update user lifecycle info' = 'microsoft.directory/users/lifeCycleInfo/update'
                    'update user authorization info' = 'microsoft.directory/users/authorizationInfo/update'
                    #endregion User management

                    #region Role management
                    'add member to role' = 'microsoft.directory/roleAssignments/allProperties/update'
                    'remove member from role' = 'microsoft.directory/roleAssignments/allProperties/update'
                    'add eligible member to role' = 'microsoft.directory/roleEligibilityScheduleRequest/allProperties/update'
                    'remove eligible member from role' = 'microsoft.directory/roleEligibilityScheduleRequest/allProperties/update'
                    'add scoped member to role' = 'microsoft.directory/roleAssignments/allProperties/update'
                    'remove scoped member from role' = 'microsoft.directory/roleAssignments/allProperties/update'
                    'add role definition' = 'microsoft.directory/roleDefinitions/allProperties/allTasks'
                    'update role definition' = 'microsoft.directory/roleDefinitions/allProperties/allTasks'
                    'delete role definition' = 'microsoft.directory/roleDefinitions/allProperties/allTasks'
                    'add role assignment' = 'microsoft.directory/roleAssignments/allProperties/allTasks'
                    'remove role assignment' = 'microsoft.directory/roleAssignments/allProperties/allTasks'
                    'add scoped role membership' = 'microsoft.directory/scopedRoleMemberships/allProperties/allTasks'
                    'remove scoped role membership' = 'microsoft.directory/scopedRoleMemberships/allProperties/allTasks'
                    #endregion Role management

                    #region Application management
                    'add application' = 'microsoft.directory/applications/create'
                    'delete application' = 'microsoft.directory/applications/delete'
                    'update application' = 'microsoft.directory/applications/basic/update'
                    'restore application' = 'microsoft.directory/applications/delete'
                    'hard delete application' = 'microsoft.directory/applications/delete'
                    'add service principal' = 'microsoft.directory/servicePrincipals/create'
                    'delete service principal' = 'microsoft.directory/servicePrincipals/delete'
                    'update service principal' = 'microsoft.directory/servicePrincipals/basic/update'
                    'disable service principal' = 'microsoft.directory/servicePrincipals/disable'
                    'enable service principal' = 'microsoft.directory/servicePrincipals/enable'
                    'add service principal credentials' = 'microsoft.directory/servicePrincipals/credentials/update'
                    'remove service principal credentials' = 'microsoft.directory/servicePrincipals/credentials/update'
                    'update service principal credentials' = 'microsoft.directory/servicePrincipals/credentials/update'
                    'add app role assignment to service principal' = 'microsoft.directory/servicePrincipals/appRoleAssignment/update'
                    'remove app role assignment from service principal' = 'microsoft.directory/servicePrincipals/appRoleAssignment/update'
                    'add owner to application' = 'microsoft.directory/applications/owners/update'
                    'remove owner from application' = 'microsoft.directory/applications/owners/update'
                    'add owner to service principal' = 'microsoft.directory/servicePrincipals/owners/update'
                    'remove owner from service principal' = 'microsoft.directory/servicePrincipals/owners/update'
                    'consent to application' = 'microsoft.directory/servicePrincipals/appRoleAssignment/update'
                    'add app role assignment grant to user' = 'microsoft.directory/servicePrincipals/appRoleAssignment/update'
                    'remove app role assignment grant from user' = 'microsoft.directory/servicePrincipals/appRoleAssignment/update'
                    'add delegated permission grant' = 'microsoft.directory/oAuth2PermissionGrants/allProperties/update'
                    'remove delegated permission grant' = 'microsoft.directory/oAuth2PermissionGrants/delete'
                    'update delegated permission grant' = 'microsoft.directory/oAuth2PermissionGrants/allProperties/update'
                    'add application certificate and secret management' = 'microsoft.directory/applications/credentials/update'
                    'update application certificates and secrets management' = 'microsoft.directory/applications/credentials/update'
                    'remove application certificate and secret management' = 'microsoft.directory/applications/credentials/update'
                    'update application authentication' = 'microsoft.directory/applications/authentication/update'
                    'update application audience' = 'microsoft.directory/applications/audience/update'
                    'update application permissions' = 'microsoft.directory/applications/permissions/update'
                    'update application app roles' = 'microsoft.directory/applications/appRoles/update'
                    'update application policies' = 'microsoft.directory/applications/policies/update'
                    'update application tags' = 'microsoft.directory/applications/tag/update'
                    'update application notes' = 'microsoft.directory/applications/notes/update'
                    'update application extension properties' = 'microsoft.directory/applications/extensionProperties/update'
                    'update application proxy' = 'microsoft.directory/applications/applicationProxy/update'
                    'update application proxy authentication' = 'microsoft.directory/applications/applicationProxyAuthentication/update'
                    'update application proxy ssl certificate' = 'microsoft.directory/applications/applicationProxySslCertificate/update'
                    'update application proxy url settings' = 'microsoft.directory/applications/applicationProxyUrlSettings/update'
                    'update application verification' = 'microsoft.directory/applications/verification/update'
                    'update application disablement' = 'microsoft.directory/applications/disablement/update'
                    'update service principal authentication' = 'microsoft.directory/servicePrincipals/authentication/update'
                    'update service principal audience' = 'microsoft.directory/servicePrincipals/audience/update'
                    'update service principal permissions' = 'microsoft.directory/servicePrincipals/permissions/update'
                    'update service principal policies' = 'microsoft.directory/servicePrincipals/policies/update'
                    'update service principal notes' = 'microsoft.directory/servicePrincipals/notes/update'
                    'update service principal tags' = 'microsoft.directory/servicePrincipals/tag/update'
                    'instantiate application template' = 'microsoft.directory/applicationTemplates/instantiate'
                    #endregion Application management

                    #region Application policy management
                    'add application policy' = 'microsoft.directory/applicationPolicies/create'
                    'update application policy' = 'microsoft.directory/applicationPolicies/basic/update'
                    'delete application policy' = 'microsoft.directory/applicationPolicies/delete'
                    'update application policy owners' = 'microsoft.directory/applicationPolicies/owners/update'
                    #endregion Application policy management

                    #region Application proxy connector management
                    'add connector group' = 'microsoft.directory/connectorGroups/create'
                    'update connector group' = 'microsoft.directory/connectorGroups/allProperties/update'
                    'delete connector group' = 'microsoft.directory/connectorGroups/delete'
                    'add connector' = 'microsoft.directory/connectors/create'
                    #endregion Application proxy connector management

                    #region Device management
                    'add device' = 'microsoft.directory/devices/create'
                    'delete device' = 'microsoft.directory/devices/delete'
                    'update device' = 'microsoft.directory/devices/basic/update'
                    'add registered owner to device' = 'microsoft.directory/devices/registeredOwners/update'
                    'remove registered owner from device' = 'microsoft.directory/devices/registeredOwners/update'
                    'add registered users to device' = 'microsoft.directory/devices/registeredUsers/update'
                    'remove registered users from device' = 'microsoft.directory/devices/registeredUsers/update'
                    'register device' = 'microsoft.directory/devices/create'
                    'unregister device' = 'microsoft.directory/devices/delete'
                    'enable device' = 'microsoft.directory/devices/enable'
                    'disable device' = 'microsoft.directory/devices/disable'
                    'update device permissions' = 'microsoft.directory/devices/permissions/update'
                    'update device extension attributes' = 'microsoft.directory/devices/extensionAttributeSet1/update'
                    'hard delete device' = 'microsoft.directory/devices/delete'
                    'restore device' = 'microsoft.directory/devices/create'
                    #endregion Device management

                    #region Policy management
                    'set company information' = 'microsoft.directory/organization/basic/update'
                    'update policy' = 'microsoft.directory/policies/basic/update'
                    'add policy' = 'microsoft.directory/policies/create'
                    'delete policy' = 'microsoft.directory/policies/delete'
                    'set password policy' = 'microsoft.directory/organization/basic/update'
                    'update policy owners' = 'microsoft.directory/policies/owners/update'
                    'set company branding' = 'microsoft.directory/loginOrganizationBranding/allProperties/allTasks'
                    'update company branding' = 'microsoft.directory/loginOrganizationBranding/allProperties/allTasks'
                    'delete company branding' = 'microsoft.directory/loginOrganizationBranding/allProperties/allTasks'
                    'update organization settings' = 'microsoft.directory/organization/basic/update'
                    'update authorization policy' = 'microsoft.directory/authorizationPolicy/allProperties/allTasks'
                    'update strong authentication policy' = 'microsoft.directory/organization/strongAuthentication/allTasks'
                    #endregion Policy management

                    #region Conditional access
                    'add conditional access policy' = 'microsoft.directory/conditionalAccessPolicies/create'
                    'update conditional access policy' = 'microsoft.directory/conditionalAccessPolicies/basic/update'
                    'delete conditional access policy' = 'microsoft.directory/conditionalAccessPolicies/delete'
                    'update conditional access policy owners' = 'microsoft.directory/conditionalAccessPolicies/owners/update'
                    'set conditional access policy default' = 'microsoft.directory/conditionalAccessPolicies/tenantDefault/update'
                    #endregion Conditional access

                    #region Directory management
                    'update domain' = 'microsoft.directory/domains/allProperties/update'
                    'add domain to company' = 'microsoft.directory/domains/allProperties/update'
                    'remove unverified domain' = 'microsoft.directory/domains/allProperties/update'
                    'verify domain' = 'microsoft.directory/domains/allProperties/update'
                    'set domain authentication' = 'microsoft.directory/domains/allProperties/update'
                    'add partner to company' = 'microsoft.directory/partners/create'
                    'remove partner from company' = 'microsoft.directory/partners/delete'
                    'update federation configuration' = 'microsoft.directory/domains/federationConfiguration/basic/update'
                    'add federation configuration' = 'microsoft.directory/domains/federationConfiguration/create'
                    'delete federation configuration' = 'microsoft.directory/domains/federationConfiguration/delete'
                    'set domain federation settings' = 'microsoft.directory/domains/federation/update'
                    'update directory sync property' = 'microsoft.directory/organization/dirSync/update'
                    #endregion Directory management

                    #region Administrative unit management
                    'add administrative unit' = 'microsoft.directory/administrativeUnits/allProperties/allTasks'
                    'update administrative unit' = 'microsoft.directory/administrativeUnits/allProperties/allTasks'
                    'delete administrative unit' = 'microsoft.directory/administrativeUnits/allProperties/allTasks'
                    'add member to administrative unit' = 'microsoft.directory/administrativeUnits/members/update'
                    'remove member from administrative unit' = 'microsoft.directory/administrativeUnits/members/update'
                    #endregion Administrative unit management

                    #region Named location management
                    'add named location' = 'microsoft.directory/namedLocations/create'
                    'update named location' = 'microsoft.directory/namedLocations/basic/update'
                    'delete named location' = 'microsoft.directory/namedLocations/delete'
                    #endregion Named location management

                    #region Authentication methods
                    'admin registered security info' = 'microsoft.directory/users/authenticationMethods/create'
                    'admin deleted security info' = 'microsoft.directory/users/authenticationMethods/delete'
                    'admin updated security info' = 'microsoft.directory/users/authenticationMethods/basic/update'
                    #endregion Authentication methods

                    #region Contact management
                    'add contact' = 'microsoft.directory/contacts/create'
                    'update contact' = 'microsoft.directory/contacts/basic/update'
                    'delete contact' = 'microsoft.directory/contacts/delete'
                    #endregion Contact management

                    #region Group settings management (directory-level groupSettings objects)
                    'add group setting' = 'microsoft.directory/groupSettings/create'
                    'set group setting' = 'microsoft.directory/groupSettings/basic/update'
                    'delete group setting' = 'microsoft.directory/groupSettings/delete'
                    #endregion Group settings management

                    #region OAuth2 permission grant management
                    'add oauth2permissiongrant' = 'microsoft.directory/oAuth2PermissionGrants/create'
                    'update oauth2permissiongrant' = 'microsoft.directory/oAuth2PermissionGrants/basic/update'
                    'remove oauth2permissiongrant' = 'microsoft.directory/oAuth2PermissionGrants/delete'
                    #endregion OAuth2 permission grant management

                    #region Service principal creation policy
                    'add service principal creation policy' = 'microsoft.directory/servicePrincipalCreationPolicies/create'
                    'update service principal creation policy' = 'microsoft.directory/servicePrincipalCreationPolicies/basic/update'
                    'delete service principal creation policy' = 'microsoft.directory/servicePrincipalCreationPolicies/delete'
                    #endregion Service principal creation policy

                    #region Permission grant policy management
                    'add permission grant policy' = 'microsoft.directory/permissionGrantPolicies/create'
                    'update permission grant policy' = 'microsoft.directory/permissionGrantPolicies/basic/update'
                    'delete permission grant policy' = 'microsoft.directory/permissionGrantPolicies/delete'
                    #endregion Permission grant policy management

                    #region Custom authentication extension management
                    'add custom authentication extension' = 'microsoft.directory/customAuthenticationExtensions/allProperties/allTasks'
                    'update custom authentication extension' = 'microsoft.directory/customAuthenticationExtensions/allProperties/allTasks'
                    'delete custom authentication extension' = 'microsoft.directory/customAuthenticationExtensions/allProperties/allTasks'
                    #endregion Custom authentication extension management

                    #region Cross-tenant access policy management
                    'update cross tenant access policy' = 'microsoft.directory/crossTenantAccessPolicy/basic/update'
                    'add cross tenant access partner' = 'microsoft.directory/crossTenantAccessPolicy/partners/create'
                    'update cross tenant access partner' = 'microsoft.directory/crossTenantAccessPolicy/partners/b2bCollaboration/update'
                    'delete cross tenant access partner' = 'microsoft.directory/crossTenantAccessPolicy/partners/delete'
                    'update cross tenant sync policy' = 'microsoft.directory/crossTenantAccessPolicy/partners/identitySynchronization/basic/update'
                    'add cross tenant sync policy' = 'microsoft.directory/crossTenantAccessPolicy/partners/identitySynchronization/create'
                    #endregion Cross-tenant access policy management

                    #region Identity protection
                    'update identity protection policy' = 'microsoft.directory/identityProtection/allProperties/update'
                    #endregion Identity protection

                    #region Entitlement management
                    'add entitlement management resource' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'update entitlement management resource' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'delete entitlement management resource' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'add access package' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'update access package' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'delete access package' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'add access package assignment' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'update access package assignment' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'remove access package assignment' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'add access package catalog' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'update access package catalog' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'delete access package catalog' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'add access package assignment policy' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'update access package assignment policy' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    'delete access package assignment policy' = 'microsoft.directory/entitlementManagement/allProperties/allTasks'
                    #endregion Entitlement management

                    #region Lifecycle workflows
                    'add lifecycle workflow' = 'microsoft.directory/lifecycleWorkflows/workflows/allProperties/allTasks'
                    'update lifecycle workflow' = 'microsoft.directory/lifecycleWorkflows/workflows/allProperties/allTasks'
                    'delete lifecycle workflow' = 'microsoft.directory/lifecycleWorkflows/workflows/allProperties/allTasks'
                    'run lifecycle workflow' = 'microsoft.directory/lifecycleWorkflows/workflows/allProperties/allTasks'
                    #endregion Lifecycle workflows

                    #region Access review management
                    'add access review' = 'microsoft.directory/accessReviews/allProperties/allTasks'
                    'update access review' = 'microsoft.directory/accessReviews/allProperties/allTasks'
                    'delete access review' = 'microsoft.directory/accessReviews/allProperties/allTasks'
                    #endregion Access review management

                    #region Privileged Identity Management
                    'add pim request' = 'microsoft.directory/privilegedIdentityManagement/allProperties/read'
                    'approve pim request' = 'microsoft.directory/privilegedIdentityManagement/allProperties/read'
                    'set pim settings' = 'microsoft.directory/privilegedIdentityManagement/allProperties/read'
                    #endregion Privileged Identity Management

                    #region User credential policy management
                    'add user credential policy' = 'microsoft.directory/userCredentialPolicies/create'
                    'update user credential policy' = 'microsoft.directory/userCredentialPolicies/basic/update'
                    'delete user credential policy' = 'microsoft.directory/userCredentialPolicies/delete'
                    #endregion User credential policy management

                    #region Verifiable credentials
                    'add verifiable credential configuration' = 'microsoft.directory/verifiableCredentials/configuration/create'
                    'update verifiable credential configuration' = 'microsoft.directory/verifiableCredentials/configuration/allProperties/update'
                    'delete verifiable credential configuration' = 'microsoft.directory/verifiableCredentials/configuration/delete'
                    'add verifiable credential contract' = 'microsoft.directory/verifiableCredentials/configuration/contracts/create'
                    'update verifiable credential contract' = 'microsoft.directory/verifiableCredentials/configuration/contracts/allProperties/update'
                    'revoke verifiable credential card' = 'microsoft.directory/verifiableCredentials/configuration/contracts/cards/revoke'
                    #endregion Verifiable credentials

                    #region B2C trust framework
                    'add trust framework policy' = 'microsoft.directory/b2cTrustFrameworkPolicy/allProperties/allTasks'
                    'update trust framework policy' = 'microsoft.directory/b2cTrustFrameworkPolicy/allProperties/allTasks'
                    'delete trust framework policy' = 'microsoft.directory/b2cTrustFrameworkPolicy/allProperties/allTasks'
                    'add trust framework key set' = 'microsoft.directory/b2cTrustFrameworkKeySet/allProperties/allTasks'
                    'update trust framework key set' = 'microsoft.directory/b2cTrustFrameworkKeySet/allProperties/allTasks'
                    'delete trust framework key set' = 'microsoft.directory/b2cTrustFrameworkKeySet/allProperties/allTasks'
                    #endregion B2C trust framework

                    #region Identity provider management
                    'add identity provider' = 'microsoft.directory/identityProviders/allProperties/allTasks'
                    'update identity provider' = 'microsoft.directory/identityProviders/allProperties/allTasks'
                    'delete identity provider' = 'microsoft.directory/identityProviders/allProperties/allTasks'
                    #endregion Identity provider management

                    #region External user profile management
                    'add external user profile' = 'microsoft.directory/pendingExternalUserProfiles/create'
                    'update external user profile' = 'microsoft.directory/externalUserProfiles/basic/update'
                    'delete external user profile' = 'microsoft.directory/externalUserProfiles/delete'
                    #endregion External user profile management

                    #region Multi-tenant organization
                    'create multi-tenant organization' = 'microsoft.directory/multiTenantOrganization/create'
                    'update multi-tenant organization' = 'microsoft.directory/multiTenantOrganization/basic/update'
                    'add tenant to multi-tenant organization' = 'microsoft.directory/multiTenantOrganization/tenants/create'
                    'remove tenant from multi-tenant organization' = 'microsoft.directory/multiTenantOrganization/tenants/delete'
                    'join multi-tenant organization' = 'microsoft.directory/multiTenantOrganization/joinRequest/organizationDetails/update'
                    #endregion Multi-tenant organization

                    #region Custom security attribute management
                    'add custom security attribute definition' = 'microsoft.directory/customSecurityAttributeDefinitions/allProperties/allTasks'
                    'update custom security attribute definition' = 'microsoft.directory/customSecurityAttributeDefinitions/allProperties/allTasks'
                    'add attribute set' = 'microsoft.directory/attributeSets/allProperties/allTasks'
                    'update attribute set' = 'microsoft.directory/attributeSets/allProperties/allTasks'
                    'update custom security attributes on user' = 'microsoft.directory/users/customSecurityAttributes/update'
                    'update custom security attributes on device' = 'microsoft.directory/devices/customSecurityAttributes/update'
                    'update custom security attributes on service principal' = 'microsoft.directory/servicePrincipals/customSecurityAttributes/update'
                    #endregion Custom security attribute management

                    #region Device management policy
                    'update device management policy' = 'microsoft.directory/deviceManagementPolicies/basic/update'
                    'update device registration policy' = 'microsoft.directory/deviceRegistrationPolicy/basic/update'
                    #endregion Device management policy

                    #region Deleted items management
                    'restore deleted item' = 'microsoft.directory/deletedItems/restore'
                    'permanently delete item' = 'microsoft.directory/deletedItems/delete'
                    #endregion Deleted items management

                    #region Hybrid authentication / password hash sync
                    'update hybrid authentication policy' = 'microsoft.directory/hybridAuthenticationPolicy/allProperties/allTasks'
                    'update password hash sync' = 'microsoft.directory/passwordHashSync/allProperties/allTasks'
                    #endregion Hybrid authentication / password hash sync

                    #region IoT device management
                    'add device template' = 'microsoft.directory/certificateBasedDeviceAuthConfigurations/create'
                    'update device template' = 'microsoft.directory/certificateBasedDeviceAuthConfigurations/credentials/update'
                    'delete device template' = 'microsoft.directory/certificateBasedDeviceAuthConfigurations/delete'
                    'update device template owners' = 'microsoft.directory/deviceTemplates/owners/update'
                    #endregion IoT device management

                    #region Tenant governance
                    'add tenant governance invitation' = 'microsoft.directory/tenantGovernance/invitations/create'
                    'delete tenant governance invitation' = 'microsoft.directory/tenantGovernance/invitations/delete'
                    'add tenant governance relationship' = 'microsoft.directory/tenantGovernance/relationships/create'
                    'update tenant governance relationship' = 'microsoft.directory/tenantGovernance/relationships/allProperties/update'
                    'add tenant governance policy template' = 'microsoft.directory/tenantGovernance/policyTemplates/create'
                    'update tenant governance policy template' = 'microsoft.directory/tenantGovernance/policyTemplates/allProperties/update'
                    'delete tenant governance policy template' = 'microsoft.directory/tenantGovernance/policyTemplates/delete'
                    'update tenant governance settings' = 'microsoft.directory/tenantGovernance/settings/allProperties/update'
                    #endregion Tenant governance
                }
                $script:hashEntraIdActivityMap = $hashActivityMap
            }

            $strLowerActivity = $ActivityDisplayName.Trim().ToLowerInvariant()

            if ($hashActivityMap.ContainsKey($strLowerActivity)) {
                $strMappedAction = $hashActivityMap[$strLowerActivity]
                if ($boolVerbose) {
                    Write-Verbose ("Mapped activity '{0}' to '{1}'." -f $ActivityDisplayName, $strMappedAction)
                }
                return $strMappedAction
            }

            # Unmapped activities return $null. Only activities with
            # explicit entries in the mapping table produce action
            # strings. This excludes self-service events (password
            # resets by users, security info registration) and
            # informational audit entries that are not real assignable
            # Entra ID custom role permissions.
            if ($boolVerbose) {
                Write-Verbose ("No mapping found for activity '{0}' (category '{1}'); returning null (not a known administrative action)." -f $ActivityDisplayName, $Category)
            }
            return $null
        } catch {
            Write-Debug ("ConvertTo-EntraIdResourceAction failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
