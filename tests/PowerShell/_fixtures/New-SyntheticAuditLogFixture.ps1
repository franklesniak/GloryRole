function New-SyntheticAuditLogFixture {
    # .SYNOPSIS
    # Generates a deterministic array of synthetic Entra ID audit log
    # rows matching the post-KQL-projection shape that
    # Get-EntraIdAuditEventFromLogAnalytics receives from
    # Invoke-AzOperationalInsightsQuery.Results.
    # .DESCRIPTION
    # Produces an array of [pscustomobject] instances whose properties
    # match the | project clause of the KQL query in
    # Get-EntraIdAuditEventFromLogAnalytics.ps1. The fixture is fully
    # deterministic: given the same parameters and seed, the output is
    # byte-identical across Windows PowerShell 5.1, PowerShell 7.4.x,
    # 7.5.x, and 7.6.x.
    #
    # All randomness flows from a single System.Random instance seeded
    # from -Seed. No calls to New-Guid or [Guid]::NewGuid() are made;
    # GUIDs are constructed from 16 random bytes via [Guid]::new($bytes).
    #
    # Retry-duplicate rows share PrincipalKey, PrincipalType,
    # PrincipalUPN, AppId, OperationName, Category, and CorrelationId
    # with their parent; TimeGenerated and RecordId differ.
    #
    # The function does not write to disk or hit the network. All
    # generation is pure in-memory.
    # .PARAMETER Count
    # Total number of rows to emit. Default 10000.
    # .PARAMETER DuplicateRatio
    # Fraction of rows that are retry-duplicates of an earlier row
    # sharing the same CorrelationId. Range 0.0-0.95. Default 0.5.
    # .PARAMETER NullCorrelationIdRatio
    # Fraction of rows with an empty CorrelationId, matching the
    # documented "Optional GUID" behavior of the AuditLogs schema.
    # Range 0.0-1.0. Default 0.02.
    # .PARAMETER UnmappedActivityRatio
    # Fraction of rows whose OperationName does not appear in the
    # ConvertTo-EntraIdResourceAction mapping table. Range 0.0-1.0.
    # Default 0.1.
    # .PARAMETER CategoryMix
    # Categories to distribute rows across uniformly.
    # Default @('UserManagement', 'GroupManagement', 'RoleManagement',
    # 'ApplicationManagement').
    # .PARAMETER ServicePrincipalRatio
    # Fraction of rows initiated by a service principal rather than a
    # user. Range 0.0-1.0. Default 0.2.
    # .PARAMETER Seed
    # RNG seed for reproducibility. Default 42.
    # .EXAMPLE
    # $arrFixture = @(New-SyntheticAuditLogFixture -Count 100 -Seed 42)
    # # Generates 100 deterministic synthetic audit log rows.
    # .EXAMPLE
    # $arrFixture = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.25 -Seed 99)
    # # Generates 500 rows with 25% retry-duplicates using seed 99.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] Synthetic audit log rows matching the
    # post-projection shape of the KQL query in
    # Get-EntraIdAuditEventFromLogAnalytics.
    # .NOTES
    # PRIVATE/INTERNAL HELPER -- This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function supports positional parameters
    # (internal-caller contract only; subject to change):
    #   Position 0: Count
    #
    # Version: 1.1.20260420.0

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'The "New-" verb constructs in-memory synthetic fixture rows; no external or system state is modified, so ShouldProcess support is not applicable.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', 'NullCorrelationIdRatio',
        Justification = 'Parameter is captured by the $scriptblockNewOriginalRow closure.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', 'UnmappedActivityRatio',
        Justification = 'Parameter is captured by the $scriptblockNewOriginalRow closure.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', 'CategoryMix',
        Justification = 'Parameter is captured by the $scriptblockNewOriginalRow closure.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', 'ServicePrincipalRatio',
        Justification = 'Parameter is captured by the $scriptblockNewOriginalRow closure.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Count = 10000,

        [ValidateRange(0.0, 0.95)]
        [double]$DuplicateRatio = 0.5,

        [ValidateRange(0.0, 1.0)]
        [double]$NullCorrelationIdRatio = 0.02,

        [ValidateRange(0.0, 1.0)]
        [double]$UnmappedActivityRatio = 0.1,

        [string[]]$CategoryMix = @('UserManagement', 'GroupManagement', 'RoleManagement', 'ApplicationManagement'),

        [ValidateRange(0.0, 1.0)]
        [double]$ServicePrincipalRatio = 0.2,

        [int]$Seed = 42
    )

    process {
        # Scope StrictMode to this function so dot-sourcing the file does not
        # enable StrictMode in the caller's session.
        Set-StrictMode -Version Latest

        # --- Mapped activity names (subset of ConvertTo-EntraIdResourceAction keys) ---
        # These are canonical activity display names. Lookup against the
        # mapping table lowercases them, and this representative subset
        # covers the four default categories.
        $arrMappedActivities = @(
            'Add member to group'
            'Remove member from group'
            'Add group'
            'Delete group'
            'Update group'
            'Add user'
            'Delete user'
            'Update user'
            'Reset user password'
            'Add member to role'
            'Remove member from role'
            'Add role definition'
            'Add application'
            'Delete application'
            'Update application'
            'Add service principal'
            'Delete service principal'
            'Update service principal'
            'Add conditional access policy'
            'Update conditional access policy'
        )

        $objRandom = New-Object System.Random($Seed)

        # Helper: generate a deterministic GUID from the seeded RNG.
        # Uses 16 random bytes -> [Guid]::new($bytes).
        $scriptblockNewGuid = {
            $arrBytes = New-Object byte[] 16
            $objRandom.NextBytes($arrBytes)
            return ([Guid]::new($arrBytes)).ToString()
        }

        # Fixed reference date for TimeGenerated window (30 days ending here).
        $dtReferenceEnd = [datetimeoffset]::new(2026, 1, 15, 0, 0, 0, [timespan]::Zero)
        $intWindowSeconds = 30 * 24 * 3600  # 30 days in seconds

        # Pre-compute counts for each row type.
        $intDuplicateCount = [Math]::Round($Count * $DuplicateRatio)
        $intOriginalCount = $Count - $intDuplicateCount

        # Helper: emit one synthetic original (non-duplicate) row for a given
        # row index. The index drives SyntheticUnmapped-{n} and user UPN
        # formatting; all randomness flows through $objRandom in a fixed
        # order so output is deterministic for a given seed.
        $scriptblockNewOriginalRow = {
            param([int]$intRowIndex)

            $dblUnmappedRoll = $objRandom.NextDouble()
            $boolUnmapped = $dblUnmappedRoll -lt $UnmappedActivityRatio

            $intCategoryIndex = $objRandom.Next(0, $CategoryMix.Count)
            $strCategory = $CategoryMix[$intCategoryIndex]

            if ($boolUnmapped) {
                $strOperationName = ('SyntheticUnmapped-{0}' -f $intRowIndex)
            } else {
                $intActivityIndex = $objRandom.Next(0, $arrMappedActivities.Count)
                $strOperationName = $arrMappedActivities[$intActivityIndex]
            }

            $dblSpRoll = $objRandom.NextDouble()
            $boolIsServicePrincipal = $dblSpRoll -lt $ServicePrincipalRatio

            $strPrincipalKey = & $scriptblockNewGuid
            $strPrincipalUPN = ''
            $strAppId = ''
            $strPrincipalType = 'User'

            if ($boolIsServicePrincipal) {
                $strPrincipalType = 'ServicePrincipal'
                $strAppId = $strPrincipalKey
                $strPrincipalUPN = ''
            } else {
                $strPrincipalUPN = ('user-{0}@contoso.example' -f $intRowIndex)
            }

            $dblNullCorrRoll = $objRandom.NextDouble()
            $strCorrelationId = ''
            if ($dblNullCorrRoll -ge $NullCorrelationIdRatio) {
                $strCorrelationId = & $scriptblockNewGuid
            }

            $strRecordId = & $scriptblockNewGuid

            $intOffsetSeconds = $objRandom.Next(0, $intWindowSeconds)
            $dtTimeGenerated = $dtReferenceEnd.AddSeconds(-$intOffsetSeconds)
            $strTimeGenerated = $dtTimeGenerated.ToString('yyyy-MM-ddTHH:mm:ssZ')

            return [pscustomobject]@{
                TimeGenerated = $strTimeGenerated
                OperationName = $strOperationName
                Category = $strCategory
                PrincipalKey = $strPrincipalKey
                PrincipalType = $strPrincipalType
                PrincipalUPN = $strPrincipalUPN
                AppId = $strAppId
                CorrelationId = $strCorrelationId
                RecordId = $strRecordId
            }
        }

        # Build the original (non-duplicate) rows first.
        $arrOriginals = New-Object System.Collections.Generic.List[pscustomobject]
        for ($i = 0; $i -lt $intOriginalCount; $i++) {
            [void]($arrOriginals.Add((& $scriptblockNewOriginalRow $i)))
        }

        # Build duplicate rows by copying parent fields and regenerating
        # TimeGenerated + RecordId.
        $arrAllRows = New-Object System.Collections.Generic.List[pscustomobject]
        foreach ($objOriginal in $arrOriginals) {
            [void]($arrAllRows.Add($objOriginal))
        }

        # Only originals with a non-empty CorrelationId can be duplicated.
        $arrDuplicateCandidates = New-Object System.Collections.Generic.List[pscustomobject]
        foreach ($objOriginal in $arrOriginals) {
            if (-not [string]::IsNullOrEmpty($objOriginal.CorrelationId)) {
                [void]($arrDuplicateCandidates.Add($objOriginal))
            }
        }

        # Tracks the next row index to pass to the fallback-original helper
        # when there are no duplicate candidates available. Starts after the
        # already-emitted originals so SyntheticUnmapped-{n} and
        # user-{n}@contoso.example remain unique.
        $intFallbackIndex = $intOriginalCount

        for ($i = 0; $i -lt $intDuplicateCount; $i++) {
            if ($arrDuplicateCandidates.Count -eq 0) {
                # No candidates available for duplication (e.g.,
                # -NullCorrelationIdRatio 1.0 left every original with an
                # empty CorrelationId). Emit an additional original row so
                # the caller still gets exactly -Count rows as contracted
                # by the parameter name and the "Emits the requested -Count
                # of rows" test in New-SyntheticAuditLogFixture.Tests.ps1.
                [void]($arrAllRows.Add((& $scriptblockNewOriginalRow $intFallbackIndex)))
                $intFallbackIndex++
                continue
            }

            $intParentIndex = $objRandom.Next(0, $arrDuplicateCandidates.Count)
            $objParent = $arrDuplicateCandidates[$intParentIndex]

            # Duplicate: same fields except TimeGenerated and RecordId.
            $intOffsetSeconds = $objRandom.Next(0, $intWindowSeconds)
            $dtTimeGenerated = $dtReferenceEnd.AddSeconds(-$intOffsetSeconds)
            $strTimeGenerated = $dtTimeGenerated.ToString('yyyy-MM-ddTHH:mm:ssZ')

            $strRecordId = & $scriptblockNewGuid

            $objDuplicate = [pscustomobject]@{
                TimeGenerated = $strTimeGenerated
                OperationName = $objParent.OperationName
                Category = $objParent.Category
                PrincipalKey = $objParent.PrincipalKey
                PrincipalType = $objParent.PrincipalType
                PrincipalUPN = $objParent.PrincipalUPN
                AppId = $objParent.AppId
                CorrelationId = $objParent.CorrelationId
                RecordId = $strRecordId
            }

            [void]($arrAllRows.Add($objDuplicate))
        }

        return $arrAllRows.ToArray()
    }
}
