BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strSrcPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Remove-DuplicateCanonicalEvent.ps1')
}

Describe "Remove-DuplicateCanonicalEvent" {
    Context "When events share the same composite key" {
        It "Collapses duplicate events to one, retaining the earliest TimeGenerated" {
            # Arrange
            $dtEarlier = [datetime]'2026-01-01T00:00:00Z'
            $dtLater = [datetime]'2026-01-01T00:01:00Z'
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = 'abc'; TimeGenerated = $dtLater }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = 'abc'; TimeGenerated = $dtEarlier }
            )

            # Act
            $arrResult = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].TimeGenerated | Should -Be $dtEarlier
        }
    }

    Context "When events belong to different composite keys" {
        It "Deduplicates each group independently" {
            # Arrange
            $dtBase = [datetime]'2026-01-01T00:00:00Z'
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = 'abc'; TimeGenerated = $dtBase }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = 'abc'; TimeGenerated = $dtBase.AddSeconds(1) }
                [pscustomobject]@{ PrincipalKey = 'user2'; Action = 'write'; ResourceId = '/sub/rg2'; CorrelationId = 'def'; TimeGenerated = $dtBase }
                [pscustomobject]@{ PrincipalKey = 'user2'; Action = 'write'; ResourceId = '/sub/rg2'; CorrelationId = 'def'; TimeGenerated = $dtBase.AddSeconds(1) }
            )

            # Act
            $arrResult = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 2
        }
    }

    Context "When CorrelationId is null" {
        It "Always keeps events with null CorrelationId" {
            # Arrange
            $dtBase = [datetime]'2026-01-01T00:00:00Z'
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = $null; TimeGenerated = $dtBase }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = $null; TimeGenerated = $dtBase.AddSeconds(1) }
            )

            # Act
            $arrResult = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 2
        }
    }

    Context "When CorrelationId is empty or whitespace" {
        It "Keeps events with empty string CorrelationId" {
            # Arrange
            $dtBase = [datetime]'2026-01-01T00:00:00Z'
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = ''; TimeGenerated = $dtBase }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = ''; TimeGenerated = $dtBase.AddSeconds(1) }
            )

            # Act
            $arrResult = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 2
        }

        It "Keeps events with whitespace-only CorrelationId" {
            # Arrange
            $dtBase = [datetime]'2026-01-01T00:00:00Z'
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = '   '; TimeGenerated = $dtBase }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = '   '; TimeGenerated = $dtBase.AddSeconds(1) }
            )

            # Act
            $arrResult = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 2
        }
    }

    Context "When events differ in Action or CorrelationId" {
        It "Retains both events with different Actions" {
            # Arrange
            $dtBase = [datetime]'2026-01-01T00:00:00Z'
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = 'abc'; TimeGenerated = $dtBase }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'write'; ResourceId = '/sub/rg'; CorrelationId = 'abc'; TimeGenerated = $dtBase }
            )

            # Act
            $arrResult = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 2
        }

        It "Retains both events with different CorrelationIds" {
            # Arrange
            $dtBase = [datetime]'2026-01-01T00:00:00Z'
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = 'abc'; TimeGenerated = $dtBase }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = 'def'; TimeGenerated = $dtBase }
            )

            # Act
            $arrResult = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 2
        }
    }

    Context "When ResourceId is null" {
        It "Deduplicates events with null ResourceId to one" {
            # Arrange
            $dtBase = [datetime]'2026-01-01T00:00:00Z'
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = $null; CorrelationId = 'abc'; TimeGenerated = $dtBase }
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = $null; CorrelationId = 'abc'; TimeGenerated = $dtBase.AddSeconds(1) }
            )

            # Act
            $arrResult = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].TimeGenerated | Should -Be $dtBase
        }
    }

    Context "When a single event is passed" {
        It "Returns the single event unchanged" {
            # Arrange
            $dtBase = [datetime]'2026-01-01T00:00:00Z'
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = 'abc'; TimeGenerated = $dtBase }
            )

            # Act
            $arrResult = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].PrincipalKey | Should -Be 'user1'
            $arrResult[0].TimeGenerated | Should -Be $dtBase
        }
    }

    Context "When an empty array is passed" {
        It "Throws a parameter binding error" {
            # Arrange / Act / Assert
            # The Events parameter is mandatory [object[]], so an empty
            # array is rejected at parameter-binding time.
            { Remove-DuplicateCanonicalEvent -Events @() } | Should -Throw
        }
    }

    Context "When verifying property preservation" {
        It "Retains all original properties including extra properties" {
            # Arrange
            $dtBase = [datetime]'2026-01-01T00:00:00Z'
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; ResourceId = '/sub/rg'; CorrelationId = 'abc'; TimeGenerated = $dtBase; Status = 'Succeeded' }
            )

            # Act
            $arrResult = @(Remove-DuplicateCanonicalEvent -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].PrincipalKey | Should -Be 'user1'
            $arrResult[0].Action | Should -Be 'read'
            $arrResult[0].ResourceId | Should -Be '/sub/rg'
            $arrResult[0].CorrelationId | Should -Be 'abc'
            $arrResult[0].TimeGenerated | Should -Be $dtBase
            $arrResult[0].Status | Should -Be 'Succeeded'
        }
    }

    Context "When malformed input is passed" {
        It "Throws a terminating error for malformed input" {
            # Arrange
            $arrMalformed = @(1, 2, 3)

            # Act / Assert
            { Remove-DuplicateCanonicalEvent -Events $arrMalformed } | Should -Throw
        }

        It "Throws a terminating error when ErrorAction is Stop" {
            # Arrange
            $arrMalformed = @(1, 2, 3)

            # Act / Assert
            { Remove-DuplicateCanonicalEvent -Events $arrMalformed -ErrorAction Stop } | Should -Throw
        }
    }
}
