BeforeAll {
    # Stub function that mimics the real Az.OperationalInsights cmdlet so Pester
    # can Mock it without importing Az.OperationalInsights in CI. The
    # parameters exist to match the real cmdlet's interface (callers set them),
    # and the body intentionally does nothing.
    function Invoke-AzOperationalInsightsQuery {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSReviewUnusedParameter', '',
            Justification = 'Parameters exist to mirror the stubbed cmdlet signature so Pester Mocks bind correctly.')]
        [CmdletBinding()]
        param ($WorkspaceId, $Query)
    }

    function Select-MockRowByKqlTimeWindow {
        # .SYNOPSIS
        # Filters mock Log Analytics rows by the time window embedded in
        # the KQL query.
        # .DESCRIPTION
        # Since the production function now issues one KQL per chunk of
        # the [Start, End] range, a naive mock that returns every row
        # unconditionally would N-fold-duplicate rows across chunks.
        # This helper parses the first two datetime(...) tokens from
        # the query -- which always correspond to the chunk's lower
        # and upper TimeGenerated bounds -- and returns only the rows
        # whose TimeGenerated falls in that window, honoring the
        # half-open-vs-closed upper-bound distinction that the
        # production code uses to coordinate chunk boundaries with the
        # overall [Start, End] interval.
        # .PARAMETER Query
        # The KQL query passed to the mock.
        # .PARAMETER Rows
        # The full set of mock rows to filter.
        # .EXAMPLE
        # $strKql = "TimeGenerated >= datetime(2026-01-10T00:00:00Z) and TimeGenerated < datetime(2026-01-11T00:00:00Z)"
        # $arrFiltered = Select-MockRowByKqlTimeWindow -Query $strKql -Rows $arrAllRows
        # # $arrFiltered contains only rows whose TimeGenerated falls
        # # in the [2026-01-10T00:00:00Z, 2026-01-11T00:00:00Z) window
        # # (half-open upper bound because the KQL uses `<`, not `<=`).
        # .INPUTS
        # None. You can't pipe objects to this function.
        # .OUTPUTS
        # [object[]] The filtered rows.
        # .NOTES
        # PRIVATE/INTERNAL HELPER -- This function is not part of the
        # public API surface. It exists only to support time-window-
        # aware mocking of the Log Analytics query cmdlet.
        #
        # Version: 1.1.20260422.0
        [CmdletBinding()]
        [OutputType([object[]])]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Query,
            [object[]]$Rows
        )

        if ($null -eq $Rows -or $Rows.Count -eq 0) {
            return @()
        }

        $regexDt = [regex]'datetime\(([^)]+)\)'
        $objMatches = $regexDt.Matches($Query)
        if ($objMatches.Count -lt 2) {
            # Fall back to returning all rows when the query shape is
            # not recognized (e.g., a future query form).
            return @($Rows)
        }

        $dtStyles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
        $objCulture = [System.Globalization.CultureInfo]::InvariantCulture
        $dtLower = [datetime]::Parse($objMatches[0].Groups[1].Value, $objCulture, $dtStyles)
        $dtUpper = [datetime]::Parse($objMatches[1].Groups[1].Value, $objCulture, $dtStyles)

        # Closed upper bound is signalled by "<= datetime(...)" (terminal
        # chunk); half-open by "< datetime(...)". The legacy
        # `between(... .. ...)` form is closed at both ends.
        $boolClosedUpper = $false
        if ($Query -match 'between\s*\(') {
            $boolClosedUpper = $true
        } elseif ($Query -match '<=\s*datetime\(') {
            $boolClosedUpper = $true
        }

        $arrFiltered = New-Object System.Collections.Generic.List[object]
        foreach ($objRow in $Rows) {
            $strTg = [string]$objRow.TimeGenerated
            if ([string]::IsNullOrWhiteSpace($strTg)) {
                # Rows with missing TimeGenerated can't be assigned to
                # any chunk by time. Include them only in the terminal
                # (closed-upper) chunk so the function sees them
                # exactly once, which preserves coverage of the
                # function's client-side "skip rows with missing
                # TimeGenerated" branch.
                if ($boolClosedUpper) {
                    [void]($arrFiltered.Add($objRow))
                }
                continue
            }
            $dtRowParsed = [datetime]::MinValue
            $boolRowParsed = [datetime]::TryParse($strTg, $objCulture, $dtStyles, [ref]$dtRowParsed)
            if (-not $boolRowParsed) {
                # Same rationale as the missing-TimeGenerated branch:
                # include in the terminal chunk only so the function's
                # unparseable-TimeGenerated branch is exercised exactly
                # once.
                if ($boolClosedUpper) {
                    [void]($arrFiltered.Add($objRow))
                }
                continue
            }
            if ($dtRowParsed -lt $dtLower) { continue }
            if ($boolClosedUpper) {
                if ($dtRowParsed -gt $dtUpper) { continue }
            } else {
                if ($dtRowParsed -ge $dtUpper) { continue }
            }
            [void]($arrFiltered.Add($objRow))
        }
        return $arrFiltered.ToArray()
    }

    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-EntraIdResourceAction.ps1')
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-EntraIdAuditEventFromLogAnalytics.ps1')
}

Describe "Get-EntraIdAuditEventFromLogAnalytics" {
    Context "When query returns valid Entra ID audit rows" {
        It "Streams CanonicalEntraIdEvent objects with correct properties" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            $objMockResults = @(
                [pscustomobject]@{
                    TimeGenerated = '2026-02-15T10:30:00Z'
                    OperationName = 'Add member to group'
                    Category = 'GroupManagement'
                    PrincipalKey = 'user-guid-001'
                    PrincipalType = 'User'
                    PrincipalUPN = 'admin@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-001'
                    RecordId = 'rec-001'
                }
                [pscustomobject]@{
                    TimeGenerated = '2026-02-16T14:00:00Z'
                    OperationName = 'Add user'
                    Category = 'UserManagement'
                    PrincipalKey = 'user-guid-002'
                    PrincipalType = 'User'
                    PrincipalUPN = 'admin2@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-002'
                    RecordId = 'rec-002'
                }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = @(Select-MockRowByKqlTimeWindow -Query $Query -Rows $objMockResults) }
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult | Should -HaveCount 2
            $arrResult[0].PSObject.TypeNames | Should -Contain 'CanonicalEntraIdEvent'
            $arrResult[0].PrincipalKey | Should -Be 'user-guid-001'
            $arrResult[0].PrincipalType | Should -Be 'User'
            $arrResult[0].Action | Should -Be 'microsoft.directory/groups/members/update'
            $arrResult[0].Result | Should -Be 'success'
            $arrResult[0].Category | Should -Be 'GroupManagement'
            $arrResult[0].ActivityDisplayName | Should -Be 'Add member to group'
            $arrResult[0].CorrelationId | Should -Be 'corr-001'
            $arrResult[0].PrincipalUPN | Should -Be 'admin@contoso.com'
            $arrResult[0].TimeGenerated | Should -BeOfType [datetime]

            $arrResult[1].PrincipalKey | Should -Be 'user-guid-002'
            $arrResult[1].Action | Should -Be 'microsoft.directory/users/create'
        }
    }

    Context "When activity is unmapped" {
        It "Skips records with unmapped activity display names" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            $objMockResults = @(
                [pscustomobject]@{
                    TimeGenerated = '2026-02-15T10:30:00Z'
                    OperationName = 'Add member to group'
                    Category = 'GroupManagement'
                    PrincipalKey = 'user-guid-001'
                    PrincipalType = 'User'
                    PrincipalUPN = 'admin@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-001'
                    RecordId = 'rec-001'
                }
                [pscustomobject]@{
                    TimeGenerated = '2026-02-15T11:00:00Z'
                    OperationName = 'Self-service password reset flow activity progress'
                    Category = 'UserManagement'
                    PrincipalKey = 'user-guid-002'
                    PrincipalType = 'User'
                    PrincipalUPN = 'user@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-002'
                    RecordId = 'rec-002'
                }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = @(Select-MockRowByKqlTimeWindow -Query $Query -Rows $objMockResults) }
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd)

            # Assert - only the mapped activity is emitted
            $arrResult | Should -HaveCount 1
            $arrResult[0].PrincipalKey | Should -Be 'user-guid-001'
        }
    }

    Context "When query returns empty results" {
        It "Produces no output" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = @() }
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult | Should -HaveCount 0
        }
    }

    Context "When query fails" {
        It "Throws a descriptive error message" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            Mock Invoke-AzOperationalInsightsQuery {
                throw "Connection timed out"
            }

            # Act / Assert
            { Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd } | Should -Throw '*Connection timed out*'
        }
    }

    Context "When action casing must be preserved" {
        It "Preserves camelCase segments in microsoft.directory/* actions" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            $objMockResults = @(
                [pscustomobject]@{
                    TimeGenerated = '2026-02-15T10:30:00Z'
                    OperationName = 'Consent to application'
                    Category = 'ApplicationManagement'
                    PrincipalKey = 'user-guid-001'
                    PrincipalType = 'User'
                    PrincipalUPN = 'admin@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-001'
                    RecordId = 'rec-001'
                }
                [pscustomobject]@{
                    TimeGenerated = '2026-02-16T14:00:00Z'
                    OperationName = 'Invite external user'
                    Category = 'UserManagement'
                    PrincipalKey = 'user-guid-002'
                    PrincipalType = 'User'
                    PrincipalUPN = 'admin2@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-002'
                    RecordId = 'rec-002'
                }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = @(Select-MockRowByKqlTimeWindow -Query $Query -Rows $objMockResults) }
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd)

            # Assert - camelCase segments are preserved (case-sensitive check)
            $arrResult | Should -HaveCount 2
            # 'Consent to application' maps to
            # microsoft.directory/servicePrincipals/appRoleAssignment/update
            ($arrResult[0].Action -ceq 'microsoft.directory/servicePrincipals/appRoleAssignment/update') | Should -BeTrue
            # 'Invite external user' maps to
            # microsoft.directory/users/inviteGuest
            ($arrResult[1].Action -ceq 'microsoft.directory/users/inviteGuest') | Should -BeTrue
            # Verify lowercase variants are absent
            ($arrResult[0].Action -ceq 'microsoft.directory/serviceprincipals/approleassignment/update') | Should -BeFalse
            ($arrResult[1].Action -ceq 'microsoft.directory/users/inviteguest') | Should -BeFalse
        }
    }

    Context "When TimeGenerated is missing or unparseable" {
        It "Skips records with missing TimeGenerated" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            $objMockResults = @(
                [pscustomobject]@{
                    TimeGenerated = '2026-02-15T10:30:00Z'
                    OperationName = 'Add member to group'
                    Category = 'GroupManagement'
                    PrincipalKey = 'user-guid-001'
                    PrincipalType = 'User'
                    PrincipalUPN = 'admin@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-001'
                    RecordId = 'rec-001'
                }
                [pscustomobject]@{
                    TimeGenerated = ''
                    OperationName = 'Add user'
                    Category = 'UserManagement'
                    PrincipalKey = 'user-guid-002'
                    PrincipalType = 'User'
                    PrincipalUPN = 'admin2@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-002'
                    RecordId = 'rec-002'
                }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = @(Select-MockRowByKqlTimeWindow -Query $Query -Rows $objMockResults) }
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd)

            # Assert - only the row with a valid TimeGenerated is emitted
            $arrResult | Should -HaveCount 1
            $arrResult[0].PrincipalKey | Should -Be 'user-guid-001'
        }
    }

    Context "When ServicePrincipal is the initiator" {
        It "Emits events with PrincipalType ServicePrincipal and AppId" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            $objMockResults = @(
                [pscustomobject]@{
                    TimeGenerated = '2026-02-15T10:30:00Z'
                    OperationName = 'Add member to group'
                    Category = 'GroupManagement'
                    PrincipalKey = 'app-guid-001'
                    PrincipalType = 'ServicePrincipal'
                    PrincipalUPN = ''
                    AppId = 'app-guid-001'
                    CorrelationId = 'corr-001'
                    RecordId = 'rec-001'
                }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = @(Select-MockRowByKqlTimeWindow -Query $Query -Rows $objMockResults) }
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult | Should -HaveCount 1
            $arrResult[0].PrincipalType | Should -Be 'ServicePrincipal'
            $arrResult[0].AppId | Should -Be 'app-guid-001'
            $arrResult[0].PrincipalUPN | Should -BeNullOrEmpty
        }
    }

    Context "When UnmappedActivityAccumulator is provided" {
        It "Populates the accumulator for unmapped activities" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            $hashUnmapped = @{}

            $objMockResults = @(
                [pscustomobject]@{
                    TimeGenerated = '2026-02-15T10:30:00Z'
                    OperationName = 'Add member to group'
                    Category = 'GroupManagement'
                    PrincipalKey = 'user-guid-001'
                    PrincipalType = 'User'
                    PrincipalUPN = 'admin@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-001'
                    RecordId = 'rec-001'
                }
                [pscustomobject]@{
                    TimeGenerated = '2026-02-15T11:00:00Z'
                    OperationName = 'Self-service password reset flow activity progress'
                    Category = 'UserManagement'
                    PrincipalKey = 'user-guid-002'
                    PrincipalType = 'User'
                    PrincipalUPN = 'user@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-002'
                    RecordId = 'rec-002'
                }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = @(Select-MockRowByKqlTimeWindow -Query $Query -Rows $objMockResults) }
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd -UnmappedActivityAccumulator $hashUnmapped)

            # Assert - only mapped event is returned
            $arrResult | Should -HaveCount 1
            $arrResult[0].PrincipalKey | Should -Be 'user-guid-001'

            # Assert - accumulator has the unmapped activity
            $hashUnmapped.Count | Should -Be 1
            $strExpectedKey = 'Self-service password reset flow activity progress|UserManagement'
            $hashUnmapped.ContainsKey($strExpectedKey) | Should -BeTrue
            $hashUnmapped[$strExpectedKey].ActivityDisplayName | Should -Be 'Self-service password reset flow activity progress'
            $hashUnmapped[$strExpectedKey].Category | Should -Be 'UserManagement'
            $hashUnmapped[$strExpectedKey].Count | Should -Be 1
            $hashUnmapped[$strExpectedKey].SampleCorrelationId | Should -Be 'corr-002'
            $hashUnmapped[$strExpectedKey].SampleRecordId | Should -Be 'rec-002'
        }

        It "Increments count for repeated unmapped activities" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            $hashUnmapped = @{}

            $objMockResults = @(
                [pscustomobject]@{
                    TimeGenerated = '2026-02-15T10:30:00Z'
                    OperationName = 'User registered security info'
                    Category = 'UserManagement'
                    PrincipalKey = 'user-guid-001'
                    PrincipalType = 'User'
                    PrincipalUPN = 'user1@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-001'
                    RecordId = 'rec-001'
                }
                [pscustomobject]@{
                    TimeGenerated = '2026-02-15T11:00:00Z'
                    OperationName = 'User registered security info'
                    Category = 'UserManagement'
                    PrincipalKey = 'user-guid-002'
                    PrincipalType = 'User'
                    PrincipalUPN = 'user2@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-002'
                    RecordId = 'rec-002'
                }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = @(Select-MockRowByKqlTimeWindow -Query $Query -Rows $objMockResults) }
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd -UnmappedActivityAccumulator $hashUnmapped)

            # Assert - no mapped events
            $arrResult | Should -HaveCount 0

            # Assert - accumulator has one entry with count 2
            $hashUnmapped.Count | Should -Be 1
            $strExpectedKey = 'User registered security info|UserManagement'
            $hashUnmapped[$strExpectedKey].Count | Should -Be 2
            # Sample IDs come from the first occurrence
            $hashUnmapped[$strExpectedKey].SampleCorrelationId | Should -Be 'corr-001'
        }

        It "Does not populate accumulator when parameter is not provided" {
            # Arrange
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'

            $objMockResults = @(
                [pscustomobject]@{
                    TimeGenerated = '2026-02-15T10:30:00Z'
                    OperationName = 'User registered security info'
                    Category = 'UserManagement'
                    PrincipalKey = 'user-guid-001'
                    PrincipalType = 'User'
                    PrincipalUPN = 'user@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-001'
                    RecordId = 'rec-001'
                }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = @(Select-MockRowByKqlTimeWindow -Query $Query -Rows $objMockResults) }
            }

            # Act - should not throw even though unmapped activities exist
            $arrResult = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd)

            # Assert
            $arrResult | Should -HaveCount 0
        }

        It "Does not track rows with unparseable TimeGenerated as unmapped" {
            # Arrange - row has an unmapped activity but its
            # TimeGenerated string cannot be parsed. The row is dropped
            # for a timestamp/data-quality reason, not for a mapping
            # coverage gap, so the accumulator MUST NOT be touched.
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            $hashUnmapped = @{}

            $objMockResults = @(
                [pscustomobject]@{
                    TimeGenerated = 'not-a-real-date'
                    OperationName = 'Self-service password reset flow activity progress'
                    Category = 'UserManagement'
                    PrincipalKey = 'user-guid-001'
                    PrincipalType = 'User'
                    PrincipalUPN = 'user@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-bad-1'
                    RecordId = 'rec-bad-1'
                }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = @(Select-MockRowByKqlTimeWindow -Query $Query -Rows $objMockResults) }
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd -UnmappedActivityAccumulator $hashUnmapped)

            # Assert
            $arrResult | Should -HaveCount 0
            $hashUnmapped.Count | Should -Be 0
        }

        It "Does not track rows with missing TimeGenerated as unmapped" {
            # Arrange - same scenario, but TimeGenerated is null. The
            # row MUST be dropped for data-quality reasons, not counted
            # as unmapped.
            $strWorkspaceId = '12345678-abcd-1234-abcd-1234567890ab'
            $dtStart = [datetime]'2026-01-01'
            $dtEnd = [datetime]'2026-03-20'
            $hashUnmapped = @{}

            $objMockResults = @(
                [pscustomobject]@{
                    TimeGenerated = $null
                    OperationName = 'Self-service password reset flow activity progress'
                    Category = 'UserManagement'
                    PrincipalKey = 'user-guid-001'
                    PrincipalType = 'User'
                    PrincipalUPN = 'user@contoso.com'
                    AppId = ''
                    CorrelationId = 'corr-null-1'
                    RecordId = 'rec-null-1'
                }
            )
            Mock Invoke-AzOperationalInsightsQuery {
                [pscustomobject]@{ Results = @(Select-MockRowByKqlTimeWindow -Query $Query -Rows $objMockResults) }
            }

            # Act
            $arrResult = @(Get-EntraIdAuditEventFromLogAnalytics -WorkspaceId $strWorkspaceId -Start $dtStart -End $dtEnd -UnmappedActivityAccumulator $hashUnmapped)

            # Assert
            $arrResult | Should -HaveCount 0
            $hashUnmapped.Count | Should -Be 0
        }
    }
}
