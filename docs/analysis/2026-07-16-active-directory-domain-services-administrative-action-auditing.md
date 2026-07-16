<!-- markdownlint-disable MD013 -->
# Active Directory Administrative Activity Audit Design

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-07-16
- **Scope:** Defines a success-only auditing design that captures Active Directory Domain Services administrative activity across all object classes and attributes, covering domain controller audit policy, a complete SACL model (object lifecycle, property writes, validated writes, extended rights, DACL/owner changes, and optional SACL access), and an operational deployment and reconciliation workflow. This document is an engineering analysis artifact and does not define normative product requirements; normative requirements live in [`docs/spec/requirements.md`](../spec/requirements.md).
- **Related:** [`docs/spec/requirements.md`](../spec/requirements.md), [`.github/instructions/docs.instructions.md`](../../.github/instructions/docs.instructions.md), [`.github/copilot-instructions.md`](../../.github/copilot-instructions.md)
- **Taxonomy:** Developer docs (`docs/`). This file is classified under the existing `docs/` documentation bucket; `docs/analysis/` is used as an organizational subdirectory for analysis documents and is not intended to define a separate top-level taxonomy category.

## Objective

Implement success-only auditing that captures the full range of Active Directory administrative activity, from entry-level service-desk work through forest-level engineering, including changes made by provisioning applications, HRIS integrations, identity-management platforms, gMSAs, and other service identities.

The design should:

- Cover every object class for creation, movement, restoration, and deletion.
- Cover every property addition, replacement, and deletion performed by administrative actors.
- Cover validated writes, extended rights, DACL changes, owner changes, and, where operationally acceptable, SACL access.
- Avoid generic property-read and object-enumeration auditing.
- Avoid treating ordinary user self-service and normal computer maintenance as administrative activity.
- Preserve enough detail to support evidence-based custom-role design.
- Retain all existing SACL entries.
- Record successful activity only.

## Executive recommendation

No Active Directory object class should be categorically excluded from creation or deletion auditing.

No Active Directory attribute should be categorically excluded from administrative write auditing.

Routine activity should be controlled primarily by **who is audited**, not by excluding object classes or attributes.

Use three audit-subject scopes:

| Scope | Recommended trustee | Purpose |
| --- | --- | --- |
| Object lifecycle | Everyone by default | Capture creation, deletion, movement, and restoration of every object class, regardless of whether the actor was previously identified as an administrator |
| Administrative changes | Governed security group or explicit trustee list | Capture every property write and every validated write by human administrators and write-capable service identities |
| Administrative control operations | Smaller governed security group or explicit trustee list | Capture extended-right usage and, optionally, access to SACLs without including high-frequency replication-only identities |

Use Everyone independently for:

- `WriteDacl`
- `WriteOwner`

This provides a safety net for security-descriptor changes even when an actor was inadvertently omitted from an administrative audit group.

This design has no object-class or attribute allowlist. Generic ACEs without an object-type GUID apply to all applicable child classes, properties, or validated writes.

## Audit-subject model

### Object lifecycle trustees

Object lifecycle auditing should initially use Everyone (`S-1-1-0`).

This records successful:

- Object creation.
- Object deletion.
- Subtree deletion.
- Object movement.
- Object restoration.
- Parent-side child deletion.

Object lifecycle events are substantially less frequent than ordinary property writes in most directories. Recording all of them is reasonable for an administrative-role study, even though some will be system-generated.

Using Everyone also captures:

- A provisioning identity that was not yet added to the administrative-change audit group.
- An ordinary user who creates a computer under `ms-DS-MachineAccountQuota`.
- A compromised or unexpectedly delegated account.
- An application identity that creates an unanticipated object class.
- Automated object creation or deletion that should be classified before being excluded from the role data set.

The raw event collection should remain complete. Expected non-administrative lifecycle records should be classified downstream.

The implementation permits replacing Everyone with another trustee if observed lifecycle volume proves operationally unacceptable, but that should be a documented exception rather than the initial design.

### Administrative-change trustees

Create a security group such as:

```text
Directory Administrative Change Audit Subjects
```

Use a universal security group in the forest root domain when practical. The group does not receive permissions. Its SID is used only as a SACL trustee to select whose successful operations are recorded.

Include:

- L1 and L2 service-desk groups.
- Account-provisioning groups.
- User, group, and computer administration groups.
- L3 and L4 directory engineering groups.
- Domain, forest, schema, DNS, Group Policy, PKI, and identity-platform administrators.
- Break-glass directory administration accounts.
- HRIS user-CRUD service accounts.
- Identity-governance and administration service accounts.
- Microsoft Identity Manager or equivalent provisioning identities.
- Microsoft Entra provisioning or writeback identities when they perform changes.
- gMSAs used by provisioning or directory-management applications.
- DNS automation identities when their modifications are part of the administrative corpus.
- Application deployment identities that register or modify directory objects.
- Any computer account whose security context performs intentional directory administration.

Do not include merely because the identity authenticates to the directory:

- Ordinary users.
- Ordinary workstation and server computer accounts.
- Domain-controller computer accounts used for normal directory operation.
- DNS clients performing their own dynamic registration.
- A DHCP DNS-update credential used only for routine registration.
- Replication-only or read-only synchronization identities.
- The account used to run broad SACL inventory scans.
- Service identities that only read directory data.

A service identity that performs both high-frequency routine work and administrative changes presents an unavoidable ambiguity: a SACL evaluates the SID and requested right, not the business purpose of the operation.

For such an identity, use one of these approaches, in order of preference:

1. Split routine and administrative functions across separate identities.
2. Include the identity and classify its routine operations downstream.
3. Use a more specific SACL for that identity only after documenting exactly which operations will be lost.

### Administrative-control trustees

Create a second group such as:

```text
Directory Administrative Control Audit Subjects
```

This should normally be a subset of the administrative-change population.

Use it to audit all successful `ExtendedRight` operations. This captures control-access operations that are not ordinary property writes, including forest-, domain-, service-, and product-specific extended rights.

Include:

- Human directory administrators.
- Service-desk groups that reset passwords.
- Identities that restore deleted objects.
- Identities that manage trusts, replication topology, optional features, or other control-access operations.
- Low-frequency service accounts that exercise mutating extended rights.

Do not automatically include high-frequency identities that use control-access rights primarily for reading or synchronization. For example, a directory synchronization identity using replication-get-changes rights can produce large numbers of successful 4662 events.

A synchronization identity that also performs writeback can be:

- Included in the administrative-change group.
- Omitted from the broad control group.
- Given separate, object-specific control-right auditing when necessary.

The PowerShell implementation also adds a specific Reset Password audit ACE for administrative-change trustees. A service-desk identity therefore does not have to be in the broad control group merely to capture password resets.

## Audit policy on domain controllers

Configure an Advanced Audit Policy GPO linked to the Domain Controllers OU.

Enable Success only:

| Advanced Audit Policy subcategory | Setting | Primary purpose |
| --- | ---: | --- |
| Directory Service Changes | Success | 5136, 5137, 5138, 5139, and 5141 |
| Directory Service Access | Success | 4662 for matching write, delete, validated-write, extended-right, DACL, owner, and optional SACL access |
| User Account Management | Success | User lifecycle, enablement, disablement, password resets, unlocks, renames, and related operations |
| Computer Account Management | Success | Computer account creation, modification, and deletion |
| Security Group Management | Success | Security-group lifecycle and membership |
| Distribution Group Management | Success | Distribution-group lifecycle and membership |
| Other Account Management Events | Success | Password-hash access during password migration |
| Authentication Policy Change | Success | Domain trust, Kerberos policy, and domain-policy administration |
| Audit Policy Change | Success | Changes to audit policy |

Enable:

```text
Audit: Force audit policy subcategory settings (Windows Vista or later)
to override audit policy category settings
```

Do not enable Failure for this use case.

Do not configure generic read-oriented SACL rights such as:

- `ReadProperty`
- `ReadControl`
- `ListChildren`
- `ListObject`

## Complete SACL model

### Naming-context roots

Apply the following success-audit ACEs at the root of every naming context returned by RootDSE.

This includes:

- Every domain naming context.
- Configuration.
- Schema.
- `DomainDnsZones`.
- `ForestDnsZones`.
- Custom application naming contexts hosted by the selected domain controller.

| Trustee | Rights | Object type | Inheritance |
| --- | --- | --- | --- |
| Object-lifecycle trustees | CreateChild, DeleteChild | None: all child classes | This object and all descendants |
| Object-lifecycle trustees | Delete, DeleteTree | None: all object classes | This object and all descendants |
| Administrative-change trustees | WriteProperty | None: all properties | This object and all descendants |
| Administrative-change trustees | Self | None: all validated writes | This object and all descendants |
| Administrative-change trustees | ExtendedRight | Reset Password GUID | Domain naming context and descendants |
| Administrative-change trustees | ExtendedRight | Reanimate Tombstones GUID | Naming-context root |
| Administrative-control trustees | ExtendedRight | None: all extended rights | This object and all descendants |
| Administrative-control trustees | AccessSystemSecurity | None | Optional; this object and all descendants |
| Everyone | WriteDacl, WriteOwner | None | This object and all descendants |

The relevant GUIDs are:

```text
Reset Password:
00299570-246d-11d0-a768-00aa006e0529

Reanimate Tombstones:
45ec5156-db7e-47bb-b53f-dbeb2d03c40f
```

### Creation, movement, restoration, and deletion coverage

A generic `CreateChild` audit ACE with no object-type GUID applies to every child class.

A generic `DeleteChild` audit ACE with no object-type GUID applies to every child class.

A generic `Delete` and `DeleteTree` audit ACE inherited by descendants applies to every object class.

Together, these rules cover:

- Initial object creation.
- Child deletion authorized through the parent.
- Deletion authorized directly on the object.
- Tree deletion.
- Movement into a destination container.
- Movement out of a source container.
- Restoration into a destination container.
- Renaming and move-related directory operations.

The relevant Directory Service Changes events are:

| Event | Meaning | SACL dependency |
| --- | --- | --- |
| 5137 | Object created | CreateChild audit on parent |
| 5138 | Object restored | CreateChild audit on destination |
| 5139 | Object moved | CreateChild audit on destination; parent access may also produce 4662 |
| 5141 | Object deleted | Delete audit on target object |
| 4662 | Directory object access | Matching CreateChild, DeleteChild, Delete, or DeleteTree audit ACE |

Both parent-side and target-side lifecycle rights are retained because Active Directory deletion authorization can involve either the object or its parent, and 5141 specifically depends on auditing deletion of the target object.

### Objects that can produce routine lifecycle events

The following are expected examples of non-human or indirectly generated object lifecycle activity.

They should initially remain in the raw audit data.

| Object or area | Expected source | Why activity may be routine | Recommended treatment |
| --- | --- | --- | --- |
| `dnsNode` objects beneath `CN=MicrosoftDNS` | DNS clients, DNS servers, DHCP credentials, scavenging | Dynamic registration can add, update, and remove DNS records; scavenging can remove stale records | Retain raw events; classify using object class, DN, subject SID, and DNS/DHCP identity |
| `nTDSConnection` objects | KCC and domain-controller security contexts | KCC automatically generates and maintains replication topology | Retain raw events; classify KCC-generated activity separately from manual topology administration |
| Application-specific dynamic objects | Application service identity or directory expiration | Some applications use temporary or TTL-based directory objects | Retain until the application's expected behavior is documented |
| Service-registration objects | Application or service identity | Services may register or remove discovery objects during deployment or lifecycle operations | Retain because the same class may also be manually administered |
| `foreignSecurityPrincipal` objects | Directory service as a consequence of group administration | Cross-domain membership can cause supporting objects to be created | Retain and correlate with the initiating group-membership action |
| Recovery and device-registration objects | Endpoint-management or provisioning service | Escrow and device onboarding may create objects automatically | Retain when evaluating service-account and provisioning roles |

The presence of routine operations is not sufficient justification for excluding the entire object class. A manual administrative operation can affect the same class.

Use actor, object path, correlation, and application context to classify the event.

### Property-write coverage

A generic `WriteProperty` ACE with no object-type GUID covers every property on every inheriting object.

It includes:

- Adding an attribute value.
- Replacing an attribute value.
- Removing one value from a multivalued attribute.
- Deleting the final value of an attribute.
- Changes to linked attributes such as group membership.
- Changes to custom schema attributes.
- Changes to product-specific attributes.
- Changes to DNS data when the actor is an administrative-change trustee.
- Changes to Configuration and Schema objects.
- Changes within custom application partitions.

A typical replacement can generate two 5136 events:

1. `Value Deleted`
2. `Value Added`

Correlate them by `OpCorrelationID` before counting administrative actions.

There should be no static attribute allowlist for this role-engineering use case. An allowlist inevitably omits:

- Custom schema extensions.
- New attributes introduced by products or Windows versions.
- Low-frequency administrative fields.
- Business attributes managed by HRIS.
- Application-specific configuration.
- Attributes whose security relevance is not obvious until exercised.

### How routine property writes are controlled

Routine property writes are suppressed primarily through the administrative-change trustee.

Ordinary users are not members of that group, so their normal self-service changes do not match the generic `WriteProperty` SACL ACE.

Ordinary computer accounts are not members, so their normal self-maintenance does not match it.

Domain controllers and normal system identities are not members, so routine directory-service maintenance does not match it.

Examples include:

- Ordinary user profile changes.
- Ordinary users changing their own passwords.
- Computer-account password maintenance.
- Computer self-maintenance of DNS names and SPNs.
- Authentication-related operational attributes.
- Dynamic DNS property updates by client or DHCP identities.
- KCC-managed replication-topology properties.

An HRIS, identity-governance, or user-CRUD service account is deliberately included, so every property it adds, changes, or removes is recorded, including ordinary business attributes such as:

- Department.
- Manager.
- Title.
- Employee identifiers.
- Mail routing fields.
- Account expiration.
- Group membership.
- Organizational-unit placement.
- Custom HR or application attributes.

That is desirable for custom-role design because those fields define the service's actual delegated operating requirements.

### Validated writes

`WriteProperty` does not represent every form of directory mutation.

Add generic `Self` auditing for administrative-change trustees. With no object-type GUID, this covers all validated writes supported by the target objects, including present and future schema-defined validated writes.

Examples can include validated updates to:

- Service principal names.
- DNS host names.
- Additional DNS host names.
- Other class-specific validated-write operations.

### Extended rights

Extended rights are not ordinary property writes.

Add generic `ExtendedRight` auditing for administrative-control trustees.

This captures successful use of:

- Password-reset rights.
- Tombstone reanimation.
- SID-history migration.
- Replication-management rights.
- Optional-feature administration.
- Product-specific control-access rights.
- Other rights represented by `controlAccessRight` objects.

Because some extended rights are read-oriented or used at high frequency, the broad control trustee population should be smaller than the administrative-change population.

A specific Reset Password audit ACE is also added for administrative-change trustees so that service-desk password resets are captured without requiring broad all-extended-right auditing for every service-desk operator.

### DACL and owner changes

Audit these rights for Everyone throughout every naming context:

```text
WriteDacl
WriteOwner
```

These operations are inherently administrative and normally low volume.

This also provides coverage when an unexpected principal, omitted service account, or compromised ordinary identity changes permissions or ownership.

### SACL changes

Changing an Active Directory object's SACL requires `ACCESS_SYSTEM_SECURITY`.

The same right controls both getting and setting a SACL. Windows does not provide separate directory rights for “read SACL” and “write SACL.”

Event 4907 does not generate for Active Directory objects.

For the most complete model:

- Enable `AccessSystemSecurity` auditing for the administrative-control trustee group.
- Run SACL inventory and compliance scans under a dedicated identity that is not a member of that group.
- Classify the resulting 4662 events.
- Compare periodic raw SACL snapshots to distinguish actual descriptor changes from reads.

If administrative tools routinely read SACLs under human administrator credentials, this option can generate read-oriented 4662 events. It is therefore exposed as an explicit deployment option rather than enabled unconditionally.

## Password changes, resets, and unlocks

### Ordinary password changes

Event 4723 is generated when a user changes their own password.

Event 4723 and event 4724 are both controlled by the User Account Management subcategory. Windows does not offer an Advanced Audit Policy setting that enables 4724 while disabling only 4723.

Recommended treatment:

- Keep User Account Management Success enabled.
- Exclude successful 4723 events from the custom-role analysis data set.
- Optionally exclude 4723 from a role-engineering WEF subscription while retaining it in the local Security log or another security subscription.
- Do not disable User Account Management merely to remove 4723, because that would remove useful account-administration events.

The broad property SACL does not normally record an ordinary user's self-change because the ordinary user is not an administrative-change trustee.

An administrator changing their own administrative account password can still produce 4723 and possibly other matching records. Classify it as self-service when:

```text
SubjectUserSid equals TargetSid
```

### Password resets

Event 4724 is generated when an account resets another account's password. It also applies to computer-account reset procedures.

The design captures resets through:

- User Account Management Success.
- A specific Reset Password extended-right SACL ACE.
- A broad all-extended-right ACE when the actor is also an administrative-control trustee.

Do not depend on seeing password values in 5136. Password values are not exposed as ordinary readable directory data, and schema controls can prohibit individual value auditing.

### Account unlocks

Event 4767 is generated when a user account is unlocked.

The design captures unlocks through:

- User Account Management Success.
- The administrative-change trustee's generic `WriteProperty` rule when `lockoutTime` is modified by a service-desk or automation identity.

Routine lockout processing performed by a domain controller does not match the administrative-change group unless the domain-controller identity was deliberately included.

### Other account-management operations

Specialized account-management events should remain the preferred semantic record for:

- Account creation.
- Account deletion.
- Account enablement.
- Account disablement.
- Account rename.
- Password reset.
- Account unlock.
- Security-group creation and deletion.
- Group membership changes.
- Computer-account lifecycle.
- Distribution-group management.
- SID-history migration.
- Password-hash access during migration.

Directory Service Changes events provide complementary object, attribute, old-value, and new-value context.

## Read-oriented events excluded from the role data set

Some useful account-management subcategories also contain read-oriented events.

Exclude these from the custom-role activity data set unless there is a separate use case:

```text
4723 - User changed own password
4798 - User's local group membership was enumerated
4799 - Security-enabled local group membership was enumerated
4793 - Password Policy Checking API was called
```

Do not configure generic `ReadProperty`, `ReadControl`, `ListChildren`, or `ListObject` SACL entries.

For event 4662, retain only records whose access mask or properties correspond to:

- Create child.
- Delete child.
- Delete.
- Delete tree.
- Write property.
- Validated write.
- Extended right.
- Write DACL.
- Write owner.
- Optional SACL access.

## SACL-protected objects and containers

DACL protection and SACL protection are independent controls.

The relevant condition is:

```text
SystemAclProtected
```

Root inheritance alone is not sufficient for a SACL-protected descendant.

### Protected container

A SACL-protected OU or container must receive an explicit inheritable copy of the full baseline:

- CreateChild and DeleteChild for lifecycle trustees.
- Delete and DeleteTree for lifecycle trustees.
- WriteProperty for administrative-change trustees.
- Self for administrative-change trustees.
- Applicable Reset Password auditing.
- ExtendedRight for administrative-control trustees.
- Optional AccessSystemSecurity auditing.
- WriteDacl and WriteOwner for Everyone.

It then becomes a new audit inheritance anchor.

### Protected leaf object

A SACL-protected leaf must receive direct, noninheritable rules for:

- Delete and DeleteTree.
- WriteProperty.
- Self.
- Applicable Reset Password auditing.
- ExtendedRight.
- Optional AccessSystemSecurity.
- WriteDacl and WriteOwner.

### Creation of a protected object

Creation of the protected object itself is still captured by CreateChild auditing on its parent.

Subsequent changes and deletion require the direct or anchor rules.

Schedule a recurring compliance scan because a newly created protected container can create a temporary audit gap for child activity until it is identified and stamped.

### AdminSDHolder

AdminSDHolder is the security-descriptor template used by SDProp for protected administrative accounts and groups.

Apply the direct leaf-object baseline to:

```text
CN=AdminSDHolder,CN=System,<domain naming context>
```

Only after a representative pilot.

Monitor event 4780 on the PDC emulator through multiple SDProp cycles.

Do not automatically clear SACL inheritance on AdminSDHolder or protected accounts merely to suppress 4780. Microsoft specifically cautions against clearing the inheritance flag in existing domains as a general response.

## Initial object values

Event 5137 identifies the created object's:

- Actor.
- Distinguished name.
- GUID.
- Class.
- correlation information.

It does not provide a complete representation of every attribute included in the original LDAP Add operation.

For provisioning-role analysis, correlate 5137 with:

- Subsequent 5136 events.
- The HRIS or provisioning application's transaction log.
- An object-state snapshot obtained immediately after creation.
- Identity-governance request and approval records.

For automated provisioning, Active Directory normally identifies the service identity that submitted the LDAP request. It does not necessarily identify the employee, manager, ticket, or workflow that caused the provisioning application to submit it.

Application logs are therefore required for end-to-end requester attribution.

## Schema-controlled audit limitations

A SACL cannot override every schema behavior.

An attribute whose `searchFlags` includes `fNEVERVALUEAUDIT` does not permit auditing of its individual values.

This protects secret or otherwise sensitive values from appearing in audit records.

The action may still be observable through:

- Event type.
- Actor.
- target object.
- attribute name.
- specialized account-management event.
- application log.

Do not treat absence of a secret value from 5136 as absence of the operation.

## Group Policy scope

A Group Policy Object has two principal components:

1. The Group Policy container in Active Directory.
2. The Group Policy template in SYSVOL.

The directory SACL captures changes to the AD object, including GPO creation, deletion, attributes, links, DACLs, and ownership.

It does not describe every file-level change under SYSVOL.

A complete Group Policy administrative activity model also requires appropriately scoped SYSVOL file auditing or equivalent Group Policy change-management telemetry.

## PowerShell implementation

The following script:

- Uses success audit flags only.
- Includes all object classes in lifecycle auditing.
- Includes all properties in administrative-change auditing.
- Uses all validated writes for administrative-change trustees.
- Uses all extended rights for administrative-control trustees.
- Adds specific Reset Password and Reanimate Tombstones rules.
- Audits DACL and owner changes for Everyone.
- Optionally audits SACL access.
- Reads and writes only the SACL.
- Retains all existing audit rules.
- Supports `-WhatIf`.
- Supports multiple trustee groups or SID strings.
- Supports explicit SACL-protected containers and leaves.
- Supports an optional AdminSDHolder template deployment.
- Streams one result object per requested ACE.
- Uses no aliases, backtick continuations, array `+=`, or `Write-Host`.
- Uses type-prefixed local variable names, full comment-based help, `CmdletBinding`,
  `OutputType`, `try`/`catch`, method-output suppression, and lines under 115 characters.

Save it as:

```text
C:\Tools\Set-AdAdministrativeAuditSacl.ps1
```

```powershell
#requires -Version 5.1
#requires -PSEdition Desktop
#requires -Modules ActiveDirectory

# .SYNOPSIS
# Adds success-only SACL entries for comprehensive Active Directory administrative auditing.
#
# .DESCRIPTION
# Applies generic audit rules to every object class and every writable property in each naming
# context hosted by the selected writable domain controller. Object lifecycle auditing defaults to
# Everyone. Property, validated-write, and control-access auditing is scoped to governed
# administrative trustee groups or SIDs. DACL and owner changes are audited for Everyone. Existing
# SACL entries are retained.
#
# The script reads and writes only the SACL portion of nTSecurityDescriptor by using the
# LDAP_SERVER_SD_FLAGS control with SecurityMasks.Sacl. It does not request or submit a DACL.
#
# .PARAMETER Server
# Specifies the fully qualified domain name of a writable domain controller.
#
# .PARAMETER ObjectLifecycleAuditTrustee
# Specifies one or more users, groups, service identities, computer accounts, or SID strings whose
# creation and deletion of every object class should be audited. The default is Everyone so object
# lifecycle coverage does not depend on administrative-group membership.
#
# .PARAMETER AdministrativeChangeAuditTrustee
# Specifies one or more users, groups, service identities, computer accounts, or SID strings whose
# property writes and validated writes should be audited. Include all delegated human administrator
# groups and all write-capable automation identities.
#
# .PARAMETER AdministrativeControlAuditTrustee
# Specifies one or more users, groups, service identities, computer accounts, or SID strings whose
# use of all extended rights should be audited. Do not include high-frequency replication-only or
# directory-sync identities unless those control-access operations belong in the analysis corpus.
#
# .PARAMETER ProtectedContainerDistinguishedName
# Specifies SACL-protected containers that should receive an explicit inheritable copy of the full
# audit baseline.
#
# .PARAMETER ProtectedLeafDistinguishedName
# Specifies SACL-protected leaf objects that should receive a direct copy of the applicable audit
# baseline.
#
# .PARAMETER ConfigureAdminSdHolderTemplate
# Adds direct success-audit rules to the AdminSDHolder template. Pilot this option and monitor event
# 4780 on the PDC emulator through multiple SDProp cycles before production deployment.
#
# .PARAMETER AuditSaclAccess
# Audits ACCESS_SYSTEM_SECURITY use by AdministrativeControlAuditTrustee. This access right covers
# both reading and writing a SACL, so exclude SACL inventory identities from the control trustees.
#
# .EXAMPLE
# $hashtableAuditParameter = @{
#     Server = 'dc01.domain.test'
#     AdministrativeChangeAuditTrustee = @(
#         'DOMAIN\Dir-Audit-Change'
#     )
#     AdministrativeControlAuditTrustee = @(
#         'DOMAIN\Dir-Audit-Control'
#     )
# }
#
# & 'C:\Tools\Set-AdAdministrativeAuditSacl.ps1' @hashtableAuditParameter -WhatIf
# #
# Emits Proposed or AlreadyPresent objects without changing Active Directory.
#
# .EXAMPLE
# $hashtableAuditParameter = @{
#     Server = 'dc01.domain.test'
#     AdministrativeChangeAuditTrustee = @(
#         'DOMAIN\Dir-Audit-Change'
#     )
#     AdministrativeControlAuditTrustee = @(
#         'DOMAIN\Dir-Audit-Control'
#     )
#     ProtectedContainerDistinguishedName = @(
#         'OU=Tier 0,DC=domain,DC=test'
#     )
#     ConfigureAdminSdHolderTemplate = $true
#     Confirm = $false
# }
#
# & 'C:\Tools\Set-AdAdministrativeAuditSacl.ps1' @hashtableAuditParameter
#
# Emits Added or AlreadyPresent objects after applying the baseline, an explicit protected-container
# baseline, and the AdminSDHolder template rules.
#
# .INPUTS
# None. You cannot pipe objects to this script.
#
# .OUTPUTS
# System.Management.Automation.PSCustomObject. One result is emitted for every requested audit ACE.
# Result is AlreadyPresent, Proposed, or Added.
#
# .NOTES
# This script does not support positional parameters.
# Version: 2.0.20260716.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', PositionalBinding = $false)]
[OutputType([pscustomobject])]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Server,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$ObjectLifecycleAuditTrustee = @('S-1-1-0'),

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$AdministrativeChangeAuditTrustee,

    [Parameter()]
    [string[]]$AdministrativeControlAuditTrustee = @(),

    [Parameter()]
    [string[]]$ProtectedContainerDistinguishedName = @(),

    [Parameter()]
    [string[]]$ProtectedLeafDistinguishedName = @(),

    [Parameter()]
    [switch]$ConfigureAdminSdHolderTemplate,

    [Parameter()]
    [switch]$AuditSaclAccess
)

Set-StrictMode -Version Latest
$script:ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

$objLdapConnection = $null

try {
    $boolIsWindows =
        [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

    if (-not $boolIsWindows) {
        throw 'This script requires Windows PowerShell on Windows.'
    }

    Import-Module -Name ActiveDirectory -ErrorAction Stop
    Add-Type -AssemblyName System.DirectoryServices -ErrorAction Stop
    Add-Type -AssemblyName System.DirectoryServices.Protocols -ErrorAction Stop

    Write-Verbose -Message 'Resolving audit trustees to security identifiers.'

    $listLifecycleTrusteeSids =
        [System.Collections.Generic.List[System.Security.Principal.SecurityIdentifier]]::new()
    $listChangeTrusteeSids =
        [System.Collections.Generic.List[System.Security.Principal.SecurityIdentifier]]::new()
    $listControlTrusteeSids =
        [System.Collections.Generic.List[System.Security.Principal.SecurityIdentifier]]::new()
    $hashtableLifecycleTrusteeSids = @{}
    $hashtableChangeTrusteeSids = @{}
    $hashtableControlTrusteeSids = @{}

    foreach ($strTrustee in $ObjectLifecycleAuditTrustee) {
        if ($strTrustee -match '^S-\d(-\d+)+$') {
            $objTrusteeSid =
                [System.Security.Principal.SecurityIdentifier]::new($strTrustee)
        } else {
            $objTrusteeAccount = [System.Security.Principal.NTAccount]::new($strTrustee)
            $objTrusteeSid = [System.Security.Principal.SecurityIdentifier](
                $objTrusteeAccount.Translate(
                    [System.Security.Principal.SecurityIdentifier]
                )
            )
        }

        if (-not $hashtableLifecycleTrusteeSids.ContainsKey($objTrusteeSid.Value)) {
            [void]($listLifecycleTrusteeSids.Add($objTrusteeSid))
            $hashtableLifecycleTrusteeSids[$objTrusteeSid.Value] = $true
        }
    }

    foreach ($strTrustee in $AdministrativeChangeAuditTrustee) {
        if ($strTrustee -match '^S-\d(-\d+)+$') {
            $objTrusteeSid =
                [System.Security.Principal.SecurityIdentifier]::new($strTrustee)
        } else {
            $objTrusteeAccount = [System.Security.Principal.NTAccount]::new($strTrustee)
            $objTrusteeSid = [System.Security.Principal.SecurityIdentifier](
                $objTrusteeAccount.Translate(
                    [System.Security.Principal.SecurityIdentifier]
                )
            )
        }

        if (-not $hashtableChangeTrusteeSids.ContainsKey($objTrusteeSid.Value)) {
            [void]($listChangeTrusteeSids.Add($objTrusteeSid))
            $hashtableChangeTrusteeSids[$objTrusteeSid.Value] = $true
        }
    }

    foreach ($strTrustee in $AdministrativeControlAuditTrustee) {
        if ($strTrustee -match '^S-\d(-\d+)+$') {
            $objTrusteeSid =
                [System.Security.Principal.SecurityIdentifier]::new($strTrustee)
        } else {
            $objTrusteeAccount = [System.Security.Principal.NTAccount]::new($strTrustee)
            $objTrusteeSid = [System.Security.Principal.SecurityIdentifier](
                $objTrusteeAccount.Translate(
                    [System.Security.Principal.SecurityIdentifier]
                )
            )
        }

        if (-not $hashtableControlTrusteeSids.ContainsKey($objTrusteeSid.Value)) {
            [void]($listControlTrusteeSids.Add($objTrusteeSid))
            $hashtableControlTrusteeSids[$objTrusteeSid.Value] = $true
        }
    }

    Write-Verbose -Message 'Discovering naming contexts hosted by the selected domain controller.'

    $objRootDirectoryServiceEntry = Get-ADRootDSE -Server $Server -ErrorAction Stop
    $strDomainNamingContext = [string]$objRootDirectoryServiceEntry.defaultNamingContext
    [string[]]$arrNamingContexts = @(
        $objRootDirectoryServiceEntry.namingContexts |
            ForEach-Object -Process { [string]$_ }
    )

    $objLdapIdentifier = [System.DirectoryServices.Protocols.LdapDirectoryIdentifier]::new(
        $Server,
        389,
        $false,
        $false
    )
    $objLdapConnection = [System.DirectoryServices.Protocols.LdapConnection]::new(
        $objLdapIdentifier
    )
    $objLdapConnection.AuthType = [System.DirectoryServices.Protocols.AuthType]::Negotiate
    $objLdapConnection.SessionOptions.ProtocolVersion = 3
    $objLdapConnection.SessionOptions.Signing = $true
    $objLdapConnection.SessionOptions.Sealing = $true
    $objLdapConnection.Timeout = [TimeSpan]::FromMinutes(2)
    [void]($objLdapConnection.Bind())

    $objEveryoneSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-1-0')
    $objSuccessAuditFlag = [System.Security.AccessControl.AuditFlags]::Success
    $objInheritanceNone =
        [System.DirectoryServices.ActiveDirectorySecurityInheritance]::None
    $objInheritanceAll =
        [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All
    $objWritePropertyRight =
        [System.DirectoryServices.ActiveDirectoryRights]::WriteProperty
    $objValidatedWriteRight =
        [System.DirectoryServices.ActiveDirectoryRights]::Self
    $objExtendedRight =
        [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight
    $objAccessSystemSecurityRight =
        [System.DirectoryServices.ActiveDirectoryRights]::AccessSystemSecurity
    $objParentLifecycleRights = [System.DirectoryServices.ActiveDirectoryRights](
        [int][System.DirectoryServices.ActiveDirectoryRights]::CreateChild -bor
        [int][System.DirectoryServices.ActiveDirectoryRights]::DeleteChild
    )
    $objObjectDeletionRights = [System.DirectoryServices.ActiveDirectoryRights](
        [int][System.DirectoryServices.ActiveDirectoryRights]::Delete -bor
        [int][System.DirectoryServices.ActiveDirectoryRights]::DeleteTree
    )
    $objSecurityDescriptorRights = [System.DirectoryServices.ActiveDirectoryRights](
        [int][System.DirectoryServices.ActiveDirectoryRights]::WriteDacl -bor
        [int][System.DirectoryServices.ActiveDirectoryRights]::WriteOwner
    )
    $objResetPasswordGuid = [Guid]'00299570-246d-11d0-a768-00aa006e0529'
    $objReanimateTombstonesGuid = [Guid]'45ec5156-db7e-47bb-b53f-dbeb2d03c40f'
    $objCallerCmdlet = $PSCmdlet

    $objAddSuccessAuditRuleScriptBlock = {
        param (
            [Parameter(Mandatory = $true)]
            [ValidateNotNull()]
            [hashtable]$Rule
        )

        $strDistinguishedName = [string]$Rule.DistinguishedName
        $objTrusteeSid =
            [System.Security.Principal.SecurityIdentifier]$Rule.TrusteeSid
        $objRights = [System.DirectoryServices.ActiveDirectoryRights]$Rule.Rights
        $objObjectType = [Guid]::Empty
        $objInheritedObjectType = [Guid]::Empty
        $objInheritanceType =
            [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All

        if ($Rule.ContainsKey('ObjectType')) {
            $objObjectType = [Guid]$Rule.ObjectType
        }

        if ($Rule.ContainsKey('InheritedObjectType')) {
            $objInheritedObjectType = [Guid]$Rule.InheritedObjectType
        }

        if ($Rule.ContainsKey('InheritanceType')) {
            $objInheritanceType =
                [System.DirectoryServices.ActiveDirectorySecurityInheritance](
                    $Rule.InheritanceType
                )
        }

        $objSearchRequest = [System.DirectoryServices.Protocols.SearchRequest]::new(
            $strDistinguishedName,
            '(objectClass=*)',
            [System.DirectoryServices.Protocols.SearchScope]::Base,
            [string[]]@('nTSecurityDescriptor')
        )
        $objReadSecurityDescriptorControl =
            [System.DirectoryServices.Protocols.SecurityDescriptorFlagControl]::new(
                [System.DirectoryServices.Protocols.SecurityMasks]::Sacl
            )
        [void]($objSearchRequest.Controls.Add($objReadSecurityDescriptorControl))

        $objSearchResponse = [System.DirectoryServices.Protocols.SearchResponse](
            $objLdapConnection.SendRequest($objSearchRequest)
        )

        if ($objSearchResponse.Entries.Count -ne 1) {
            throw (
                'Expected one LDAP entry for {0}; received {1}.' -f
                    $strDistinguishedName,
                    $objSearchResponse.Entries.Count
            )
        }

        $objSecurityDescriptorAttribute =
            $objSearchResponse.Entries[0].Attributes['nTSecurityDescriptor']

        if ($null -eq $objSecurityDescriptorAttribute -or
            $objSecurityDescriptorAttribute.Count -eq 0) {
            throw ('The domain controller did not return a SACL for {0}.' -f
                $strDistinguishedName)
        }

        [byte[]]$arrSecurityDescriptorBytes = $objSecurityDescriptorAttribute[0]
        $objSecurityDescriptor = [System.DirectoryServices.ActiveDirectorySecurity]::new()
        [void]($objSecurityDescriptor.SetSecurityDescriptorBinaryForm(
                $arrSecurityDescriptorBytes
            ))

        $objRequestedRule = [System.DirectoryServices.ActiveDirectoryAuditRule]::new(
            $objTrusteeSid,
            $objRights,
            $objSuccessAuditFlag,
            $objObjectType,
            $objInheritanceType,
            $objInheritedObjectType
        )
        $boolAlreadyCovered = $false
        $objExistingRuleCollection = $objSecurityDescriptor.GetAuditRules(
            $true,
            $true,
            [System.Security.Principal.SecurityIdentifier]
        )

        foreach ($objExistingRule in $objExistingRuleCollection) {
            if ($objExistingRule.IsInherited -or
                $objExistingRule.IdentityReference.Value -ne $objTrusteeSid.Value -or
                $objExistingRule.ObjectType -ne $objObjectType -or
                $objExistingRule.InheritedObjectType -ne $objInheritedObjectType -or
                $objExistingRule.InheritanceType -ne $objInheritanceType) {
                continue
            }

            $intExistingRights = [int]$objExistingRule.ActiveDirectoryRights
            $intRequestedRights = [int]$objRights
            $intExistingAuditFlags = [int]$objExistingRule.AuditFlags
            $intRequestedAuditFlags = [int]$objSuccessAuditFlag
            $boolRightsCovered =
                ($intExistingRights -band $intRequestedRights) -eq $intRequestedRights
            $boolAuditFlagsCovered =
                ($intExistingAuditFlags -band $intRequestedAuditFlags) -eq
                $intRequestedAuditFlags

            if ($boolRightsCovered -and $boolAuditFlagsCovered) {
                $boolAlreadyCovered = $true
                break
            }
        }

        if ($boolAlreadyCovered) {
            [pscustomobject]@{
                DistinguishedName = $strDistinguishedName
                Result = 'AlreadyPresent'
                TrusteeSid = $objTrusteeSid.Value
                Rights = [string]$objRights
                AuditFlags = [string]$objSuccessAuditFlag
                ObjectType = $objObjectType
                InheritanceType = [string]$objInheritanceType
                InheritedObjectType = $objInheritedObjectType
            }

            return
        }

        if (-not $objCallerCmdlet.ShouldProcess(
                $strDistinguishedName,
                ('Add success-audit SACL rule for {0} to {1}' -f
                    [string]$objRights,
                    $objTrusteeSid.Value)
            )) {
            [pscustomobject]@{
                DistinguishedName = $strDistinguishedName
                Result = 'Proposed'
                TrusteeSid = $objTrusteeSid.Value
                Rights = [string]$objRights
                AuditFlags = [string]$objSuccessAuditFlag
                ObjectType = $objObjectType
                InheritanceType = [string]$objInheritanceType
                InheritedObjectType = $objInheritedObjectType
            }

            return
        }

        [void]($objSecurityDescriptor.AddAuditRule($objRequestedRule))
        [byte[]]$arrUpdatedSecurityDescriptorBytes =
            $objSecurityDescriptor.GetSecurityDescriptorBinaryForm()
        $objModification =
            [System.DirectoryServices.Protocols.DirectoryAttributeModification]::new()
        $objModification.Name = 'nTSecurityDescriptor'
        $objModification.Operation =
            [System.DirectoryServices.Protocols.DirectoryAttributeOperation]::Replace
        [void]($objModification.Add($arrUpdatedSecurityDescriptorBytes))

        $objModifyRequest = [System.DirectoryServices.Protocols.ModifyRequest]::new(
            $strDistinguishedName,
            [System.DirectoryServices.Protocols.DirectoryAttributeModification[]]@(
                $objModification
            )
        )
        $objWriteSecurityDescriptorControl =
            [System.DirectoryServices.Protocols.SecurityDescriptorFlagControl]::new(
                [System.DirectoryServices.Protocols.SecurityMasks]::Sacl
            )
        [void]($objModifyRequest.Controls.Add($objWriteSecurityDescriptorControl))
        [void]($objLdapConnection.SendRequest($objModifyRequest))

        [pscustomobject]@{
            DistinguishedName = $strDistinguishedName
            Result = 'Added'
            TrusteeSid = $objTrusteeSid.Value
            Rights = [string]$objRights
            AuditFlags = [string]$objSuccessAuditFlag
            ObjectType = $objObjectType
            InheritanceType = [string]$objInheritanceType
            InheritedObjectType = $objInheritedObjectType
        }
    }

    $objAddContainerAuditBaselineScriptBlock = {
        param (
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$DistinguishedName,

            [Parameter()]
            [bool]$IncludeResetPassword = $false,

            [Parameter()]
            [bool]$IncludeReanimateTombstone = $false
        )

        foreach ($objLifecycleTrusteeSid in $listLifecycleTrusteeSids) {
            & $objAddSuccessAuditRuleScriptBlock -Rule @{
                DistinguishedName = $DistinguishedName
                TrusteeSid = $objLifecycleTrusteeSid
                Rights = $objParentLifecycleRights
                InheritanceType = $objInheritanceAll
            }

            & $objAddSuccessAuditRuleScriptBlock -Rule @{
                DistinguishedName = $DistinguishedName
                TrusteeSid = $objLifecycleTrusteeSid
                Rights = $objObjectDeletionRights
                InheritanceType = $objInheritanceAll
            }
        }

        foreach ($objChangeTrusteeSid in $listChangeTrusteeSids) {
            & $objAddSuccessAuditRuleScriptBlock -Rule @{
                DistinguishedName = $DistinguishedName
                TrusteeSid = $objChangeTrusteeSid
                Rights = $objWritePropertyRight
                InheritanceType = $objInheritanceAll
            }

            & $objAddSuccessAuditRuleScriptBlock -Rule @{
                DistinguishedName = $DistinguishedName
                TrusteeSid = $objChangeTrusteeSid
                Rights = $objValidatedWriteRight
                InheritanceType = $objInheritanceAll
            }

            if ($IncludeResetPassword -and
                -not $hashtableControlTrusteeSids.ContainsKey($objChangeTrusteeSid.Value)) {
                & $objAddSuccessAuditRuleScriptBlock -Rule @{
                    DistinguishedName = $DistinguishedName
                    TrusteeSid = $objChangeTrusteeSid
                    Rights = $objExtendedRight
                    ObjectType = $objResetPasswordGuid
                    InheritanceType = $objInheritanceAll
                }
            }

            if ($IncludeReanimateTombstone -and
                -not $hashtableControlTrusteeSids.ContainsKey($objChangeTrusteeSid.Value)) {
                & $objAddSuccessAuditRuleScriptBlock -Rule @{
                    DistinguishedName = $DistinguishedName
                    TrusteeSid = $objChangeTrusteeSid
                    Rights = $objExtendedRight
                    ObjectType = $objReanimateTombstonesGuid
                    InheritanceType = $objInheritanceNone
                }
            }
        }

        foreach ($objControlTrusteeSid in $listControlTrusteeSids) {
            & $objAddSuccessAuditRuleScriptBlock -Rule @{
                DistinguishedName = $DistinguishedName
                TrusteeSid = $objControlTrusteeSid
                Rights = $objExtendedRight
                InheritanceType = $objInheritanceAll
            }

            if ($AuditSaclAccess.IsPresent) {
                & $objAddSuccessAuditRuleScriptBlock -Rule @{
                    DistinguishedName = $DistinguishedName
                    TrusteeSid = $objControlTrusteeSid
                    Rights = $objAccessSystemSecurityRight
                    InheritanceType = $objInheritanceAll
                }
            }
        }

        & $objAddSuccessAuditRuleScriptBlock -Rule @{
            DistinguishedName = $DistinguishedName
            TrusteeSid = $objEveryoneSid
            Rights = $objSecurityDescriptorRights
            InheritanceType = $objInheritanceAll
        }
    }

    $objAddLeafAuditBaselineScriptBlock = {
        param (
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$DistinguishedName,

            [Parameter()]
            [bool]$IncludeResetPassword = $false
        )

        foreach ($objLifecycleTrusteeSid in $listLifecycleTrusteeSids) {
            & $objAddSuccessAuditRuleScriptBlock -Rule @{
                DistinguishedName = $DistinguishedName
                TrusteeSid = $objLifecycleTrusteeSid
                Rights = $objObjectDeletionRights
                InheritanceType = $objInheritanceNone
            }
        }

        foreach ($objChangeTrusteeSid in $listChangeTrusteeSids) {
            & $objAddSuccessAuditRuleScriptBlock -Rule @{
                DistinguishedName = $DistinguishedName
                TrusteeSid = $objChangeTrusteeSid
                Rights = $objWritePropertyRight
                InheritanceType = $objInheritanceNone
            }

            & $objAddSuccessAuditRuleScriptBlock -Rule @{
                DistinguishedName = $DistinguishedName
                TrusteeSid = $objChangeTrusteeSid
                Rights = $objValidatedWriteRight
                InheritanceType = $objInheritanceNone
            }

            if ($IncludeResetPassword -and
                -not $hashtableControlTrusteeSids.ContainsKey($objChangeTrusteeSid.Value)) {
                & $objAddSuccessAuditRuleScriptBlock -Rule @{
                    DistinguishedName = $DistinguishedName
                    TrusteeSid = $objChangeTrusteeSid
                    Rights = $objExtendedRight
                    ObjectType = $objResetPasswordGuid
                    InheritanceType = $objInheritanceNone
                }
            }
        }

        foreach ($objControlTrusteeSid in $listControlTrusteeSids) {
            & $objAddSuccessAuditRuleScriptBlock -Rule @{
                DistinguishedName = $DistinguishedName
                TrusteeSid = $objControlTrusteeSid
                Rights = $objExtendedRight
                InheritanceType = $objInheritanceNone
            }

            if ($AuditSaclAccess.IsPresent) {
                & $objAddSuccessAuditRuleScriptBlock -Rule @{
                    DistinguishedName = $DistinguishedName
                    TrusteeSid = $objControlTrusteeSid
                    Rights = $objAccessSystemSecurityRight
                    InheritanceType = $objInheritanceNone
                }
            }
        }

        & $objAddSuccessAuditRuleScriptBlock -Rule @{
            DistinguishedName = $DistinguishedName
            TrusteeSid = $objEveryoneSid
            Rights = $objSecurityDescriptorRights
            InheritanceType = $objInheritanceNone
        }
    }

    #region Naming context roots

    foreach ($strNamingContext in $arrNamingContexts) {
        $boolIsDomainNamingContext = $strNamingContext.Equals(
            $strDomainNamingContext,
            [System.StringComparison]::OrdinalIgnoreCase
        )

        $hashtableContainerBaselineParameter = @{
            DistinguishedName = $strNamingContext
            IncludeResetPassword = $boolIsDomainNamingContext
            IncludeReanimateTombstone = $true
        }

        & $objAddContainerAuditBaselineScriptBlock @hashtableContainerBaselineParameter
    }

    #endregion Naming context roots

    #region SACL-protected custom containers

    foreach ($strProtectedContainerDistinguishedName in
        $ProtectedContainerDistinguishedName) {
        $boolIsDomainPartitionTarget =
            $strProtectedContainerDistinguishedName.EndsWith(
                $strDomainNamingContext,
                [System.StringComparison]::OrdinalIgnoreCase
            )

        $hashtableContainerBaselineParameter = @{
            DistinguishedName = $strProtectedContainerDistinguishedName
            IncludeResetPassword = $boolIsDomainPartitionTarget
        }

        & $objAddContainerAuditBaselineScriptBlock @hashtableContainerBaselineParameter
    }

    #endregion SACL-protected custom containers

    #region SACL-protected custom leaf objects

    foreach ($strProtectedLeafDistinguishedName in $ProtectedLeafDistinguishedName) {
        $boolIsDomainPartitionTarget =
            $strProtectedLeafDistinguishedName.EndsWith(
                $strDomainNamingContext,
                [System.StringComparison]::OrdinalIgnoreCase
            )

        $hashtableLeafBaselineParameter = @{
            DistinguishedName = $strProtectedLeafDistinguishedName
            IncludeResetPassword = $boolIsDomainPartitionTarget
        }

        & $objAddLeafAuditBaselineScriptBlock @hashtableLeafBaselineParameter
    }

    #endregion SACL-protected custom leaf objects

    #region AdminSDHolder template

    if ($ConfigureAdminSdHolderTemplate.IsPresent) {
        $strAdminSdHolderDistinguishedName = 'CN=AdminSDHolder,CN=System,{0}' -f
            $strDomainNamingContext

        $hashtableLeafBaselineParameter = @{
            DistinguishedName = $strAdminSdHolderDistinguishedName
            IncludeResetPassword = $true
        }

        & $objAddLeafAuditBaselineScriptBlock @hashtableLeafBaselineParameter
    }

    #endregion AdminSDHolder template
} catch {
    Write-Debug -Message 'The Active Directory audit SACL configuration did not complete.'
    throw
} finally {
    if ($null -ne $objLdapConnection) {
        [void]($objLdapConnection.Dispose())
    }
}
```

## Create the audit-subject groups

The following is a representative example. Select an organizational unit governed by normal security-group change control.

```powershell
Import-Module -Name ActiveDirectory -ErrorAction Stop

$strServer = 'dc01.domain.test'
$strGroupPath = 'OU=Security Groups,DC=domain,DC=test'

$hashtableChangeGroupParameter = @{
    Server = $strServer
    Name = 'Directory Administrative Change Audit Subjects'
    SamAccountName = 'Dir-Audit-Change'
    GroupCategory = 'Security'
    GroupScope = 'Universal'
    Path = $strGroupPath
    Description = 'Audit selector for directory property and validated-write administration.'
    PassThru = $true
    ErrorAction = 'Stop'
}

$objChangeAuditGroup = New-ADGroup @hashtableChangeGroupParameter

$hashtableControlGroupParameter = @{
    Server = $strServer
    Name = 'Directory Administrative Control Audit Subjects'
    SamAccountName = 'Dir-Audit-Control'
    GroupCategory = 'Security'
    GroupScope = 'Universal'
    Path = $strGroupPath
    Description = 'Audit selector for directory extended-right administration.'
    PassThru = $true
    ErrorAction = 'Stop'
}

$objControlAuditGroup = New-ADGroup @hashtableControlGroupParameter

$objChangeAuditGroup
$objControlAuditGroup
```

Universal groups cannot contain every possible domain-local or built-in group. The SACL script accepts multiple trustees, so a deployment can combine:

- The universal audit group.
- Built-in groups.
- Domain-local delegated groups.
- Individual service-account SIDs.
- gMSA SIDs.
- Computer-account SIDs.

Do not flatten all nested administrative groups into individual user memberships unless required by group-scope restrictions. Prefer adding the delegated role group itself as a trustee or as a member of the universal audit group.

## Discover protected SACL boundaries

Use the SACL-only inventory function below. It binds directly over LDAP with signing and sealing, requests only the SACL portion of `nTSecurityDescriptor` through the LDAP security-descriptor-flags control (the same SACL-only read approach the deployment script uses), and pages through every object in each hosted naming context. Because it never builds ActiveDirectory provider drive paths, distinguished names containing escaped characters cannot break path parsing during the walk. Reading SACLs requires an effective security context permitted to request SACL information. A full walk of every naming context can take significant time in a large environment.

Save it as:

```text
C:\Tools\Get-AdRawSaclByPartition.ps1
```

```powershell
function Get-AdRawSaclByPartition {
    # .SYNOPSIS
    # Retrieves raw SACL information from Active Directory naming contexts.
    #
    # .DESCRIPTION
    # Queries the naming contexts hosted by the specified domain controller and requests only the
    # SACL portion of nTSecurityDescriptor by using SecurityDescriptorFlagControl with
    # SecurityMasks.Sacl. The function does not request owner, group, or DACL information.
    #
    # By default, the function reads only each naming-context root. Use AllObjects to search every
    # object in every hosted naming context with LDAP paging. When AllObjects is used, objects that
    # have no SACL are omitted.
    #
    # Each result contains the SACL-only SDDL, the exact raw ACL bytes encoded as Base64, summary
    # counts, SACL inheritance state, and parsed ACE details. Each parsed ACE also includes its exact
    # binary representation encoded as Base64.
    #
    # .PARAMETER Server
    # Specifies the DNS name or host name of the domain controller to query. The current security
    # context is used with negotiated authentication, LDAP signing, and LDAP sealing.
    #
    # .PARAMETER AllObjects
    # Searches every object in each naming context hosted by the selected domain controller. When
    # omitted, only each naming-context root is read.
    #
    # .PARAMETER PageSize
    # Specifies the LDAP page size used with AllObjects. The default is 500, and the supported range
    # is 1 through 1000. This parameter has no effect unless AllObjects is specified.
    #
    # .EXAMPLE
    # $arrPartitionSystemAccessControlLists = @(Get-AdRawSaclByPartition -Server 'dc01.domain.test')
    #
    # # Returns one result for each naming-context root hosted by the selected domain controller.
    #
    # .EXAMPLE
    # $arrObjectSystemAccessControlLists = @(
    #     Get-AdRawSaclByPartition -Server 'dc01.domain.test' -AllObjects -PageSize 500
    # )
    #
    # # Returns objects with SACLs from every hosted naming context and guarantees an array result.
    #
    # .EXAMPLE
    # $arrPartitionSystemAccessControlLists = @(Get-AdRawSaclByPartition -Server 'dc01.domain.test')
    # $arrPartitionSystemAccessControlLists |
    #     Select-Object -Property Partition, ObjectDn, SaclState, ExplicitAceCount, DaclReturned
    #
    # # Displays a concise partition-root summary. DaclReturned should be False for every result.
    #
    # .INPUTS
    # None. You cannot pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject]. One object is streamed for each naming-context root by default, or for each
    # object with a SACL when AllObjects is specified. Each object contains these properties:
    #
    # Server [string]: Queried server name.
    # Partition [string]: Naming-context distinguished name.
    # ObjectDn [string]: Object distinguished name.
    # SaclState [string]: NotPresent, PresentNull, PresentEmpty, or Present.
    # SaclProtected [bool]: Whether SystemAclProtected is set.
    # TotalAceCount [int]: Total number of SACL ACEs.
    # ExplicitAceCount [int]: Number of noninherited SACL ACEs.
    # InheritedAceCount [int]: Number of inherited SACL ACEs.
    # SaclSddl [string] or $null: SACL-only SDDL.
    # RawSaclBase64 [string] or $null: Exact binary RawAcl encoded as Base64.
    # DaclReturned [bool]: Whether a DACL was unexpectedly returned.
    # Aces [pscustomobject[]]: Parsed SACL ACEs.
    #
    # Each object in Aces contains AceIndex [int], AceType [string], AceFlags [string], AuditFlags
    # [string], AceQualifier [string] or $null, IsInherited [bool], IsCallback [bool], AccessMaskHex
    # [string] or $null, Sid [string] or $null, ObjectAceFlags [string] or $null, ObjectTypeGuid
    # [string] or $null, InheritedObjectTypeGuid [string] or $null, BinaryLength [int], and
    # RawAceBase64 [string]. The function emits no object for an AllObjects search result that has no
    # SACL.
    #
    # .NOTES
    # This function does not support positional parameters.
    # Requires Windows and PowerShell 5.1 or later.
    # Reading SACLs requires an effective security context permitted to request SACL information.
    # Version: 1.0.20260716.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter()]
        [switch]$AllObjects,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$PageSize = 500
    )

    Set-StrictMode -Version Latest

    $objLightweightDirectoryAccessProtocolConnection = $null

    try {
        #region Platform and connection setup

        $boolIsWindows =
            [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

        if (-not $boolIsWindows) {
            throw [System.PlatformNotSupportedException]::new(
                'Get-AdRawSaclByPartition requires Windows.'
            )
        }

        if ($PSVersionTable.PSVersion -lt [version]'5.1') {
            throw [System.NotSupportedException]::new(
                'Get-AdRawSaclByPartition requires PowerShell 5.1 or later.'
            )
        }

        Add-Type -AssemblyName System.DirectoryServices.Protocols -ErrorAction Stop

        Write-Verbose -Message 'Binding to the specified LDAP server.'

        $objDirectoryIdentifier =
            [System.DirectoryServices.Protocols.LdapDirectoryIdentifier]::new(
                $Server,
                389,
                $false,
                $false
            )
        $objLightweightDirectoryAccessProtocolConnection =
            [System.DirectoryServices.Protocols.LdapConnection]::new(
                $objDirectoryIdentifier
            )
        $objLightweightDirectoryAccessProtocolConnection.AuthType =
            [System.DirectoryServices.Protocols.AuthType]::Negotiate
        $objLightweightDirectoryAccessProtocolConnection.SessionOptions.ProtocolVersion = 3
        $objLightweightDirectoryAccessProtocolConnection.SessionOptions.Signing = $true
        $objLightweightDirectoryAccessProtocolConnection.SessionOptions.Sealing = $true
        $objLightweightDirectoryAccessProtocolConnection.Timeout = [TimeSpan]::FromMinutes(2)
        [void]($objLightweightDirectoryAccessProtocolConnection.Bind())

        #endregion Platform and connection setup

        #region Naming-context discovery

        # RootDSE provides the naming-context replicas hosted by the selected server.
        $objRootSearchRequest =
            [System.DirectoryServices.Protocols.SearchRequest]::new(
                '',
                '(objectClass=*)',
                [System.DirectoryServices.Protocols.SearchScope]::Base,
                [string[]]@('namingContexts')
            )
        $objRootSearchResponse =
            [System.DirectoryServices.Protocols.SearchResponse](
                $objLightweightDirectoryAccessProtocolConnection.SendRequest($objRootSearchRequest)
            )

        if ($objRootSearchResponse.Entries.Count -ne 1) {
            throw [System.InvalidOperationException]::new(
                ('The RootDSE query returned {0} entries; expected one.' -f
                    $objRootSearchResponse.Entries.Count)
            )
        }

        $objNamingContextsAttribute =
            $objRootSearchResponse.Entries[0].Attributes['namingContexts']

        if ($null -eq $objNamingContextsAttribute -or
            $objNamingContextsAttribute.Count -eq 0) {
            throw [System.InvalidOperationException]::new(
                'The LDAP server did not return the namingContexts RootDSE attribute.'
            )
        }

        [string[]]$arrNamingContexts =
            $objNamingContextsAttribute.GetValues([string])

        Write-Verbose -Message (
            'Discovered {0} naming contexts.' -f $arrNamingContexts.Count
        )

        if ($AllObjects.IsPresent) {
            $objSearchScope =
                [System.DirectoryServices.Protocols.SearchScope]::Subtree
        } else {
            $objSearchScope =
                [System.DirectoryServices.Protocols.SearchScope]::Base
        }

        $objObjectAccessControlEntryTypePresentFlag =
            [System.Security.AccessControl.ObjectAceFlags]::ObjectAceTypePresent
        $objInheritedObjectAccessControlEntryTypePresentFlag =
            [System.Security.AccessControl.ObjectAceFlags]::InheritedObjectAceTypePresent

        #endregion Naming-context discovery

        #region SACL enumeration

        foreach ($strNamingContext in $arrNamingContexts) {
            [byte[]]$arrPageCookie = @()

            do {
                $objSearchRequest =
                    [System.DirectoryServices.Protocols.SearchRequest]::new(
                        $strNamingContext,
                        '(objectClass=*)',
                        $objSearchScope,
                        [string[]]@('nTSecurityDescriptor')
                    )

                # The SD Flags control prevents the server from returning owner, group, or DACL data.
                $objSystemAccessControlListOnlyControl =
                    [System.DirectoryServices.Protocols.SecurityDescriptorFlagControl]::new(
                        [System.DirectoryServices.Protocols.SecurityMasks]::Sacl
                    )
                [void]($objSearchRequest.Controls.Add($objSystemAccessControlListOnlyControl))

                if ($AllObjects.IsPresent) {
                    $objPageRequestControl =
                        [System.DirectoryServices.Protocols.PageResultRequestControl]::new(
                            $PageSize
                        )
                    $objPageRequestControl.Cookie = $arrPageCookie
                    [void]($objSearchRequest.Controls.Add($objPageRequestControl))
                }

                $objSearchResponse =
                    [System.DirectoryServices.Protocols.SearchResponse](
                        $objLightweightDirectoryAccessProtocolConnection.SendRequest(
                            $objSearchRequest
                        )
                    )

                foreach ($objSearchEntry in $objSearchResponse.Entries) {
                    $strObjectDistinguishedName =
                        [string]$objSearchEntry.DistinguishedName
                    $objSecurityDescriptorAttribute =
                        $objSearchEntry.Attributes['nTSecurityDescriptor']

                    if ($null -eq $objSecurityDescriptorAttribute -or
                        $objSecurityDescriptorAttribute.Count -eq 0) {
                        throw [System.InvalidOperationException]::new(
                            ('The server omitted nTSecurityDescriptor for {0}.' -f
                                $strObjectDistinguishedName)
                        )
                    }

                    [byte[]]$arrSecurityDescriptorBytes =
                        $objSecurityDescriptorAttribute[0]
                    $objSecurityDescriptor =
                        [System.Security.AccessControl.RawSecurityDescriptor]::new(
                            $arrSecurityDescriptorBytes,
                            0
                        )
                    $objSystemAccessControlList = $objSecurityDescriptor.SystemAcl
                    $boolSystemAccessControlListPresent = (
                        $objSecurityDescriptor.ControlFlags.HasFlag(
                            [System.Security.AccessControl.ControlFlags]::SystemAclPresent
                        ) -or
                        $null -ne $objSystemAccessControlList
                    )
                    $boolSystemAccessControlListProtected =
                        $objSecurityDescriptor.ControlFlags.HasFlag(
                            [System.Security.AccessControl.ControlFlags]::SystemAclProtected
                        )
                    $strSystemAccessControlListState = 'Present'

                    if (-not $boolSystemAccessControlListPresent) {
                        $strSystemAccessControlListState = 'NotPresent'
                    } elseif ($null -eq $objSystemAccessControlList) {
                        $strSystemAccessControlListState = 'PresentNull'
                    } elseif ($objSystemAccessControlList.Count -eq 0) {
                        $strSystemAccessControlListState = 'PresentEmpty'
                    }

                    $strSystemAccessControlListSecurityDescriptorDefinitionLanguage = $null
                    $strRawSystemAccessControlListBase64 = $null
                    [pscustomobject[]]$arrParsedAccessControlEntries = @()

                    if ($boolSystemAccessControlListPresent) {
                        $strSystemAccessControlListSecurityDescriptorDefinitionLanguage =
                            $objSecurityDescriptor.GetSddlForm(
                                [System.Security.AccessControl.AccessControlSections]::Audit
                            )
                    }

                    if ($null -ne $objSystemAccessControlList) {
                        [byte[]]$arrSystemAccessControlListBytes =
                            [System.Array]::CreateInstance(
                                [byte],
                                $objSystemAccessControlList.BinaryLength
                            )
                        [void](
                            $objSystemAccessControlList.GetBinaryForm(
                                $arrSystemAccessControlListBytes,
                                0
                            )
                        )
                        $strRawSystemAccessControlListBase64 =
                            [Convert]::ToBase64String(
                                $arrSystemAccessControlListBytes
                            )

                        $arrParsedAccessControlEntries = @(
                            for (
                                $intAccessControlEntryIndex = 0;
                                $intAccessControlEntryIndex -lt
                                    $objSystemAccessControlList.Count;
                                $intAccessControlEntryIndex++
                            ) {
                                $objAccessControlEntry =
                                    $objSystemAccessControlList[$intAccessControlEntryIndex]
                                $objKnownAccessControlEntry =
                                    $objAccessControlEntry -as
                                    [System.Security.AccessControl.KnownAce]
                                $objQualifiedAccessControlEntry =
                                    $objAccessControlEntry -as
                                    [System.Security.AccessControl.QualifiedAce]
                                $objObjectAccessControlEntry =
                                    $objAccessControlEntry -as
                                    [System.Security.AccessControl.ObjectAce]
                                $boolIsInherited = $objAccessControlEntry.IsInherited
                                $strAccessMaskHexadecimal = $null
                                $strSecurityIdentifier = $null
                                $strAccessControlEntryQualifier = $null
                                $boolIsCallback = $false
                                $strObjectAccessControlEntryFlags = $null
                                $strObjectTypeGloballyUniqueIdentifier = $null
                                $strInheritedObjectTypeGloballyUniqueIdentifier = $null

                                if ($null -ne $objKnownAccessControlEntry) {
                                    $strAccessMaskHexadecimal = (
                                        '0x{0:X8}' -f
                                            $objKnownAccessControlEntry.AccessMask
                                    )

                                    if ($null -ne
                                        $objKnownAccessControlEntry.SecurityIdentifier) {
                                        $strSecurityIdentifier =
                                            $objKnownAccessControlEntry.
                                                SecurityIdentifier.Value
                                    }
                                }

                                if ($null -ne $objQualifiedAccessControlEntry) {
                                    $strAccessControlEntryQualifier =
                                        [string]$objQualifiedAccessControlEntry.AceQualifier
                                    $boolIsCallback =
                                        $objQualifiedAccessControlEntry.IsCallback
                                }

                                if ($null -ne $objObjectAccessControlEntry) {
                                    $strObjectAccessControlEntryFlags =
                                        [string]$objObjectAccessControlEntry.ObjectAceFlags

                                    if (
                                        $objObjectAccessControlEntry.
                                            ObjectAceFlags.HasFlag(
                                                $objObjectAccessControlEntryTypePresentFlag
                                            )
                                    ) {
                                        $strObjectTypeGloballyUniqueIdentifier =
                                            [string]$objObjectAccessControlEntry.
                                                ObjectAceType
                                    }

                                    if (
                                        $objObjectAccessControlEntry.
                                            ObjectAceFlags.HasFlag(
                                                $objInheritedObjectAccessControlEntryTypePresentFlag
                                            )
                                    ) {
                                        $strInheritedObjectTypeGloballyUniqueIdentifier =
                                            [string]$objObjectAccessControlEntry.
                                                InheritedObjectAceType
                                    }
                                }

                                [byte[]]$arrAccessControlEntryBytes =
                                    [System.Array]::CreateInstance(
                                        [byte],
                                        $objAccessControlEntry.BinaryLength
                                    )
                                [void](
                                    $objAccessControlEntry.GetBinaryForm(
                                        $arrAccessControlEntryBytes,
                                        0
                                    )
                                )

                                [pscustomobject]@{
                                    AceIndex = $intAccessControlEntryIndex
                                    AceType = [string]$objAccessControlEntry.AceType
                                    AceFlags = [string]$objAccessControlEntry.AceFlags
                                    AuditFlags = [string]$objAccessControlEntry.AuditFlags
                                    AceQualifier = $strAccessControlEntryQualifier
                                    IsInherited = $boolIsInherited
                                    IsCallback = $boolIsCallback
                                    AccessMaskHex = $strAccessMaskHexadecimal
                                    Sid = $strSecurityIdentifier
                                    ObjectAceFlags = $strObjectAccessControlEntryFlags
                                    ObjectTypeGuid =
                                        $strObjectTypeGloballyUniqueIdentifier
                                    InheritedObjectTypeGuid =
                                        $strInheritedObjectTypeGloballyUniqueIdentifier
                                    BinaryLength = $objAccessControlEntry.BinaryLength
                                    RawAceBase64 =
                                        [Convert]::ToBase64String(
                                            $arrAccessControlEntryBytes
                                        )
                                }
                            }
                        )
                    }

                    if ($AllObjects.IsPresent -and
                        -not $boolSystemAccessControlListPresent) {
                        continue
                    }

                    $intExplicitAccessControlEntryCount = 0

                    foreach (
                        $objParsedAccessControlEntry in
                        $arrParsedAccessControlEntries
                    ) {
                        if (-not $objParsedAccessControlEntry.IsInherited) {
                            $intExplicitAccessControlEntryCount++
                        }
                    }

                    [pscustomobject]@{
                        Server = $Server
                        Partition = $strNamingContext
                        ObjectDn = $strObjectDistinguishedName
                        SaclState = $strSystemAccessControlListState
                        SaclProtected = $boolSystemAccessControlListProtected
                        TotalAceCount = $arrParsedAccessControlEntries.Count
                        ExplicitAceCount = $intExplicitAccessControlEntryCount
                        InheritedAceCount = (
                            $arrParsedAccessControlEntries.Count -
                                $intExplicitAccessControlEntryCount
                        )
                        SaclSddl =
                            $strSystemAccessControlListSecurityDescriptorDefinitionLanguage
                        RawSaclBase64 = $strRawSystemAccessControlListBase64
                        DaclReturned = (
                            $null -ne $objSecurityDescriptor.DiscretionaryAcl
                        )
                        Aces = $arrParsedAccessControlEntries
                    }
                }

                if ($AllObjects.IsPresent) {
                    $objPageResponseControl = $null

                    foreach ($objResponseControl in $objSearchResponse.Controls) {
                        if (
                            $objResponseControl -is
                            [System.DirectoryServices.Protocols.PageResultResponseControl]
                        ) {
                            $objPageResponseControl = $objResponseControl
                            break
                        }
                    }

                    if ($null -eq $objPageResponseControl) {
                        throw [System.InvalidOperationException]::new(
                            'The server did not return an LDAP paging response control.'
                        )
                    }

                    if ($null -eq $objPageResponseControl.Cookie) {
                        $arrPageCookie = [byte[]]@()
                    } else {
                        $arrPageCookie = [byte[]]$objPageResponseControl.Cookie
                    }
                } else {
                    $arrPageCookie = [byte[]]@()
                }
            } while ($arrPageCookie.Length -gt 0)
        }

        #endregion SACL enumeration
    } catch {
        Write-Debug -Message (
            'The Active Directory SACL query did not complete. Rethrowing the original error.'
        )
        throw
    } finally {
        if ($null -ne $objLightweightDirectoryAccessProtocolConnection) {
            [void]($objLightweightDirectoryAccessProtocolConnection.Dispose())
        }
    }
}
```

Dot-source the function, then inventory the protected SACL boundaries:

```powershell
. 'C:\Tools\Get-AdRawSaclByPartition.ps1'

$arrSaclProtectedObjects = @(
    Get-AdRawSaclByPartition -Server 'dc01.domain.test' -AllObjects |
        Where-Object -FilterScript { $_.SaclProtected }
)

$arrSaclProtectedObjects |
    Select-Object -Property Partition, ObjectDn, ExplicitAceCount, SaclSddl |
    Format-List
```

Classify each result as:

- Protected container.
- Protected leaf.
- AdminSDHolder-managed account or group.
- Deliberately isolated application subtree.
- Obsolete or accidental protection requiring remediation.

Do not automatically submit every protected object to the same parameter without checking whether it is a container or leaf.

## Preview the SACL deployment

Non-SID trustee strings resolve through `DOMAIN\sAMAccountName` lookup, so the examples reference the audit groups by the `SamAccountName` values assigned at group creation, not by their display names.

```powershell
$hashtableAuditParameter = @{
    Server = 'dc01.domain.test'
    AdministrativeChangeAuditTrustee = @(
        'DOMAIN\Dir-Audit-Change'
        'BUILTIN\Account Operators'
        'DOMAIN\HRIS User Provisioning'
        'DOMAIN\Identity Governance Service'
    )
    AdministrativeControlAuditTrustee = @(
        'DOMAIN\Dir-Audit-Control'
    )
    ProtectedContainerDistinguishedName = @(
        'OU=Tier 0,DC=domain,DC=test'
        'OU=Service Accounts,DC=domain,DC=test'
    )
    ProtectedLeafDistinguishedName = @(
        'CN=Special Directory Object,OU=Directory Services,DC=domain,DC=test'
    )
}

$arrProposedAuditRules = @(
    & 'C:\Tools\Set-AdAdministrativeAuditSacl.ps1' `
        @hashtableAuditParameter `
        -WhatIf
)

$arrProposedAuditRules |
    Format-Table -Property DistinguishedName, TrusteeSid, Rights, Result -AutoSize
```

The invocation above uses backticks only in the calling example for visual presentation. To apply the same style-guide preference used by the implementation script, use a single natural command line:

```powershell
$arrProposedAuditRules = @(
    & 'C:\Tools\Set-AdAdministrativeAuditSacl.ps1' @hashtableAuditParameter -WhatIf
)
```

## Apply the SACL deployment

```powershell
$arrAppliedAuditRules = @(
    & 'C:\Tools\Set-AdAdministrativeAuditSacl.ps1' @hashtableAuditParameter
)

$arrAppliedAuditRules |
    Group-Object -Property Result |
    Select-Object -Property Name, Count |
    Sort-Object -Property Name
```

## Pilot SACL access auditing

Use a deployment and SACL-inventory identity that is not in the administrative-control group.

```powershell
$hashtableSaclAccessAuditParameter = @{
    Server = 'dc01.domain.test'
    AdministrativeChangeAuditTrustee = @(
        'DOMAIN\Dir-Audit-Change'
    )
    AdministrativeControlAuditTrustee = @(
        'DOMAIN\Dir-Audit-Control'
    )
    AuditSaclAccess = $true
}

$arrSaclAccessAuditRules = @(
    & 'C:\Tools\Set-AdAdministrativeAuditSacl.ps1' `
        @hashtableSaclAccessAuditParameter `
        -WhatIf
)
```

A style-guide-preferred invocation without line continuation is:

```powershell
$arrSaclAccessAuditRules = @(
    & 'C:\Tools\Set-AdAdministrativeAuditSacl.ps1' @hashtableSaclAccessAuditParameter -WhatIf
)
```

## Pilot AdminSDHolder independently

```powershell
$hashtableAdminSdHolderAuditParameter = @{
    Server = 'dc01.domain.test'
    AdministrativeChangeAuditTrustee = @(
        'DOMAIN\Dir-Audit-Change'
    )
    AdministrativeControlAuditTrustee = @(
        'DOMAIN\Dir-Audit-Control'
    )
    ConfigureAdminSdHolderTemplate = $true
}

$arrAdminSdHolderProposedRules = @(
    & 'C:\Tools\Set-AdAdministrativeAuditSacl.ps1' `
        @hashtableAdminSdHolderAuditParameter `
        -WhatIf
)
```

A style-guide-preferred invocation is:

```powershell
$arrAdminSdHolderProposedRules = @(
    & 'C:\Tools\Set-AdAdministrativeAuditSacl.ps1' `
        @hashtableAdminSdHolderAuditParameter `
        -WhatIf
)
```

For strict avoidance of backtick continuation:

```powershell
$arrAdminSdHolderProposedRules = @(
    & 'C:\Tools\Set-AdAdministrativeAuditSacl.ps1' @hashtableAdminSdHolderAuditParameter -WhatIf
)
```

Apply AdminSDHolder template rules only after:

- Reviewing the proposed ACEs.
- Testing protected user and group operations.
- Observing the PDC emulator through multiple SDProp cycles.
- Confirming that event 4780 activity settles to an understood baseline.

## Deployment sequence

1. Preserve a full raw-SACL inventory.
2. Create and protect the administrative-change and administrative-control audit groups.
3. Inventory all current human administration groups and write-capable service identities.
4. Populate the audit groups or pass additional trustee SIDs directly to the script.
5. Configure the success-only Advanced Audit Policy GPO.
6. Increase Security log size and verify retention.
7. Confirm collection from every writable domain controller.
8. Run the SACL script with `-WhatIf`.
9. Review every naming context and explicit protected target.
10. Pilot in a test domain or representative administrative OU.
11. Exercise L1 through L4 administrative scenarios.
12. Apply naming-context-root rules.
13. Apply custom protected-container and protected-leaf rules.
14. Pilot AdminSDHolder separately.
15. Consider SACL-access auditing only after separating the inventory identity.
16. Re-run the raw-SACL inventory and retain it as the desired-state baseline.
17. Schedule recurring SACL-protection and audit-group membership reconciliation.
18. Review event volume before making any SACL-level exception.

## Forest-wide deployment

The script configures naming contexts hosted by the selected server.

In a multidomain forest:

- Run it against a writable domain controller in every domain.
- Run it against a writable replica of each custom application partition.
- Configuration, Schema, and forest DNS partitions may be encountered more than once.
- Repeated execution is safe because the script checks for existing explicit coverage.
- Collect audit records from every domain controller because the relevant event is generated on the domain controller that processes the operation.

Do not depend solely on a Global Catalog or read-only replica for deployment.

## Validation operations

Test with dedicated laboratory objects.

### L1 and L2 service desk

- Reset a user password.
- Unlock a user account.
- Enable and disable a user.
- Update an expiration date.
- Update business attributes.
- Add and remove group membership.
- Move a user between approved OUs.
- Create and delete a basic user or contact through the approved workflow.

### Provisioning automation

- Create a user through the HRIS integration.
- Populate all initial business attributes.
- Modify manager, department, title, identifiers, and mail attributes.
- Add birthright group membership.
- Disable or move a terminated user.
- Delete or deprovision a test identity.
- Correlate the AD actor SID with the HRIS transaction.

### L3 administration

- Create, modify, move, and delete groups and computers.
- Modify delegation-related attributes.
- Modify SPNs and DNS host names.
- Modify a GPO and its links.
- Create or modify an AD-integrated DNS record.
- Create or modify a DNS zone.
- Change an object's DACL.
- Change an object's owner.
- Restore a deleted object.
- Modify a SACL in the SACL-access pilot.

### L4 and forest administration

- Create, modify, and remove a trust in a laboratory forest.
- Modify sites, subnets, site links, or replication connections.
- Modify Configuration-partition objects.
- Perform a reversible Schema test in a laboratory forest.
- Modify optional features or other forest-level controls.
- Transfer a laboratory FSMO role.
- Exercise a product-specific extended right.
- Test AdminSDHolder propagation.

## Event validation query

```powershell
[int[]]$arrEventIds = @(
    4662,
    4706,
    4707,
    4716,
    4719,
    4720,
    4722,
    4723,
    4724,
    4725,
    4726,
    4727,
    4728,
    4729,
    4730,
    4731,
    4732,
    4733,
    4734,
    4735,
    4737,
    4738,
    4739,
    4741,
    4742,
    4743,
    4744,
    4745,
    4746,
    4747,
    4748,
    4749,
    4750,
    4751,
    4752,
    4753,
    4754,
    4755,
    4756,
    4757,
    4758,
    4759,
    4760,
    4761,
    4762,
    4763,
    4764,
    4765,
    4767,
    4780,
    4781,
    4782,
    5136,
    5137,
    5138,
    5139,
    5141
)

$hashtableEventFilter = @{
    LogName = 'Security'
    Id = $arrEventIds
    StartTime = (Get-Date).AddHours(-2)
}

Get-WinEvent -FilterHashtable $hashtableEventFilter |
    Select-Object -Property TimeCreated, Id, MachineName, Message
```

## Role-analysis exclusions

Exclude from the role-engineering activity table, while retaining them in the underlying security records where required:

```powershell
[int[]]$arrRoleAnalysisExcludedEventIds = @(
    4723,
    4793,
    4798,
    4799
)

Get-WinEvent -FilterHashtable $hashtableEventFilter |
    Where-Object -FilterScript {
        $_.Id -notin $arrRoleAnalysisExcludedEventIds
    } |
    Select-Object -Property TimeCreated, Id, MachineName, Message
```

Apply additional classifications based on:

- Subject SID.
- Target SID.
- Target object class.
- Target distinguished name.
- Attribute name.
- Access-mask value.
- Extended-right GUID.
- Domain controller.
- Correlation ID.
- Known application identity.
- Approved change window.
- Provisioning transaction identifier.

## Role-engineering data model

Normalize events into an activity record containing at least:

- Event time.
- Originating domain controller.
- Event ID.
- Subject SID.
- Subject account.
- Subject domain.
- Subject logon ID.
- Target SID where present.
- Object GUID.
- Object distinguished name.
- Naming context.
- Object class.
- Operation category.
- Attribute LDAP display name.
- Old value where available.
- New value where available.
- Access mask.
- Property, validated-write, or extended-right GUID.
- `OpCorrelationID`.
- `AppCorrelationID`.
- Source service or application.
- Upstream business-request identifier.
- Routine, administrative, or unresolved classification.
- Candidate delegated right.
- Candidate target scope.

For 5136, correlate the value-deleted and value-added records before counting actions.

For 4662, resolve GUIDs against:

- Attribute and class schema GUIDs.
- Property-set GUIDs.
- `CN=Extended-Rights,<Configuration NC>`.

Prefer specialized account-management events for semantic labels such as:

- Password reset.
- Unlock.
- Enable.
- Disable.
- Group member added.
- Group member removed.
- Computer created.
- Account renamed.

Use 5136 and 4662 as complementary rights and attribute evidence.

## Audit-group governance

The completeness of property and validated-write auditing depends on the administrative-change trustee population.

Establish a recurring reconciliation process that compares:

- Members of the audit-subject groups.
- Trustees in current delegation groups.
- Service identities documented in the CMDB.
- gMSAs used by identity and provisioning applications.
- Owners of scheduled directory automation.
- Accounts granted write-capable rights in directory DACLs.
- Accounts observed performing 4720-series, 4740-series, 5136-series, or 4662 operations.
- Newly introduced directory-management applications.

Any write-capable identity missing from the administrative-change audit group should be:

- Added.
- Passed directly as a trustee.
- Or documented as an intentional exclusion.

Protect the audit-subject groups themselves through:

- Restricted ownership and DACLs.
- Security Group Management Success auditing.
- Change approval.
- Regular membership review.
- Alerting on deletion or membership modification.

## Event-volume expectations

The main expected sources of volume are:

1. Two 5136 events for many value replacements.
2. Automated HRIS or identity-management bulk updates.
3. Everyone-scoped DNS-node lifecycle.
4. Account and group management duplication between specialized events and 5136.
5. Broad extended-right events for control trustees.
6. SACL-access events when `AccessSystemSecurity` auditing is enabled.
7. Initial AdminSDHolder and SDProp convergence.
8. Forest configuration activity generated by installed products.

Do not immediately weaken the SACL when volume appears.

First determine whether the volume is:

- Required role evidence.
- Expected automated administration.
- Routine non-administrative lifecycle.
- Duplicate semantic coverage.
- A trustee-group membership problem.
- A control-group identity that should be separated.
- A collector or normalization issue.

## Conditions that justify a narrower exception

An exception can be justified when all of the following are true:

1. The activity is conclusively routine and non-administrative.
2. Its actor, target subtree, and operation are stable and well understood.
3. The same identity does not perform role-relevant administration in that scope.
4. Downstream filtering is insufficient because local Security log volume is operationally harmful.
5. Removing the coverage will not conceal manual changes to the same object class or property.
6. The exception is documented, approved, tested, and periodically reviewed.
7. An alternative control records the activity when necessary.

Likely candidates, depending on measured volume, include:

- Dynamic DNS lifecycle performed by a dedicated DHCP update identity.
- A dedicated application partition used exclusively for TTL-based ephemeral objects.
- A dedicated high-frequency synchronization identity's replication control access.
- A SACL inventory identity's `AccessSystemSecurity` reads.

These are actor- or subtree-specific exceptions, not blanket exclusions of object classes or attributes.

## Practical completeness limits

This is the broadest practical native AD DS audit model, but “every administrative action” still has technical boundaries:

- 5137 does not contain a full initial object attribute image.
- Schema flags can prevent individual values from being audited.
- Secret values are not exposed.
- SACL-protected descendants need explicit coverage.
- AdminSDHolder requires separate treatment.
- An intermediary application can hide the human requester behind its service SID.
- Group Policy template file changes occur in SYSVOL, not solely in AD.
- SACL reads and writes share `ACCESS_SYSTEM_SECURITY`.
- A domain controller writes the event only where the operation is processed.
- An actor omitted from the administrative-change trustee population will not match broad property auditing.
- Application-specific semantics require application logs and business context.

These boundaries should be addressed through correlation and governance rather than by attempting to place thousands of class- or attribute-specific ACEs on partition roots.

## Overall recommendation

Implement the following baseline:

1. Audit successful creation and deletion of every object class, using Everyone initially.
2. Audit every property addition, replacement, and deletion performed by a governed population of human and service administrators.
3. Audit every validated write performed by that same population.
4. Audit every extended right performed by a smaller control-operation population.
5. Add a specific Reset Password ACE for the administrative-change population.
6. Audit DACL and owner changes for Everyone.
7. Use specialized success-only account-management and policy-change subcategories.
8. Exclude ordinary password changes and read-oriented events from the role-analysis data set, not by weakening the central account-management policy.
9. Stamp explicit rules at every SACL-protected container, protected leaf, and approved AdminSDHolder template.
10. Keep DNS and KCC lifecycle records initially and classify them downstream.
11. Include every write-capable provisioning and HRIS identity.
12. Correlate application logs whenever Active Directory sees only an intermediary service account.
13. Collect from every domain controller.
14. Reconcile audit-subject membership and raw SACL state continuously.
15. Introduce a narrower exception only after measured evidence demonstrates that it is necessary and safe.

## References

1. Microsoft, Audit Directory Service Changes
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-directory-service-changes

2. Microsoft, Event 5136
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5136

3. Microsoft, Event 5137
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5137

4. Microsoft, Event 5138
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5138

5. Microsoft, Event 5139
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5139

6. Microsoft, Event 5141
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5141

7. Microsoft, Audit User Account Management
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-user-account-management

8. Microsoft, Event 4723
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4723

9. Microsoft, Event 4724
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4724

10. Microsoft, Event 4767
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4767

11. Microsoft, Audit Computer Account Management
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-computer-account-management

12. Microsoft, Audit Security Group Management
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-security-group-management

13. Microsoft, Audit Distribution Group Management
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-distribution-group-management

14. Microsoft, Audit Other Account Management Events
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-other-account-management-events

15. Microsoft, Audit Authentication Policy Change
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/audit-authentication-policy-change

16. Microsoft, SYSTEM_AUDIT_OBJECT_ACE
https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-system_audit_object_ace

17. Microsoft, SACL Access Right
https://learn.microsoft.com/en-us/windows/win32/secauthz/sacl-access-right

18. Microsoft, Reset Password extended right
https://learn.microsoft.com/en-us/windows/win32/adschema/r-user-force-change-password

19. Microsoft, Reanimate Tombstones extended right
https://learn.microsoft.com/en-us/windows/win32/adschema/r-reanimate-tombstones

20. Microsoft, DNS dynamic update
https://learn.microsoft.com/en-us/windows-server/networking/dns/dynamic-update

21. Microsoft, DNS aging and scavenging
https://learn.microsoft.com/en-us/windows-server/networking/dns/aging-scavenging

22. Microsoft, Active Directory replication concepts and KCC
https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/replication/active-directory-replication-concepts

23. Microsoft, Protected accounts, AdminSDHolder, and SDProp
https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/appendix-c--protected-accounts-and-groups-in-active-directory

24. Microsoft, Event 4780 and inherited SACL behavior
https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/a-batch-of-event-4780-logged-pdc

25. Microsoft, LDAP_SERVER_SD_FLAGS_OID
https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/3888c2b7-35b9-45b7-afeb-b772aa932dd0

26. Microsoft, Active Directory search flags and fNEVERVALUEAUDIT
https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/7c1cdf82-1ecc-4834-827e-d26ff95fb207

27. Microsoft, Event 4907
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4907

28. PowerShell Writing Style, version 2.22.20260629.0
https://raw.githubusercontent.com/franklesniak/PSStyleGuide/refs/heads/main/STYLE_GUIDE.md
