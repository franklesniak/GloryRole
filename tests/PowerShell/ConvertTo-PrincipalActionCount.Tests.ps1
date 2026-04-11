BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strSrcPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-PrincipalActionCount.ps1')
}

Describe "ConvertTo-PrincipalActionCount" {
    Context "When given distinct events" {
        It "Basic aggregation - distinct events produce count 1.0 each" {
            # Arrange
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'userA@example.com'; Action = 'read' }
                [pscustomobject]@{ PrincipalKey = 'userB@example.com'; Action = 'write' }
            )

            # Act
            $arrResult = @(ConvertTo-PrincipalActionCount -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 2

            $arrRead = @($arrResult | Where-Object { $_.PrincipalKey -eq 'userA@example.com' -and $_.Action -eq 'read' })
            $arrRead | Should -Not -BeNullOrEmpty
            $arrRead.Count | Should -Be 1
            $arrRead[0].Count | Should -Be 1.0

            $arrWrite = @($arrResult | Where-Object { $_.PrincipalKey -eq 'userB@example.com' -and $_.Action -eq 'write' })
            $arrWrite | Should -Not -BeNullOrEmpty
            $arrWrite.Count | Should -Be 1
            $arrWrite[0].Count | Should -Be 1.0
        }
    }

    Context "When given duplicate events" {
        It "Duplicate aggregation - same principal-action pairs are summed" {
            # Arrange
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'userA@example.com'; Action = 'read' }
                [pscustomobject]@{ PrincipalKey = 'userA@example.com'; Action = 'read' }
                [pscustomobject]@{ PrincipalKey = 'userA@example.com'; Action = 'read' }
                [pscustomobject]@{ PrincipalKey = 'userA@example.com'; Action = 'write' }
            )

            # Act
            $arrResult = @(ConvertTo-PrincipalActionCount -Events $arrEvents)

            # Assert
            $arrRead = @($arrResult | Where-Object { $_.Action -eq 'read' })
            $arrRead | Should -Not -BeNullOrEmpty
            $arrRead.Count | Should -Be 1
            $arrRead[0].Count | Should -Be 3.0

            $arrWrite = @($arrResult | Where-Object { $_.Action -eq 'write' })
            $arrWrite | Should -Not -BeNullOrEmpty
            $arrWrite.Count | Should -Be 1
            $arrWrite[0].Count | Should -Be 1.0
        }

        It "Multiple principals with same action produce separate triples" {
            # Arrange
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'userA@example.com'; Action = 'read' }
                [pscustomobject]@{ PrincipalKey = 'userB@example.com'; Action = 'read' }
            )

            # Act
            $arrResult = @(ConvertTo-PrincipalActionCount -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 2

            $arrUserA = @($arrResult | Where-Object { $_.PrincipalKey -eq 'userA@example.com' })
            $arrUserA | Should -Not -BeNullOrEmpty
            $arrUserA.Count | Should -Be 1
            $arrUserA[0].Count | Should -Be 1.0

            $arrUserB = @($arrResult | Where-Object { $_.PrincipalKey -eq 'userB@example.com' })
            $arrUserB | Should -Not -BeNullOrEmpty
            $arrUserB.Count | Should -Be 1
            $arrUserB[0].Count | Should -Be 1.0
        }
    }

    Context "When given edge-case input" {
        It "Single event produces exactly one triple with count 1.0" {
            # Arrange
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'solo@example.com'; Action = 'delete' }
            )

            # Act
            $arrResult = @(ConvertTo-PrincipalActionCount -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].PrincipalKey | Should -Be 'solo@example.com'
            $arrResult[0].Action | Should -Be 'delete'
            $arrResult[0].Count | Should -Be 1.0
        }

        It "Output objects have correct property types" {
            # Arrange
            $arrEvents = @(
                [pscustomobject]@{ PrincipalKey = 'user@example.com'; Action = 'read' }
            )

            # Act
            $arrResult = @(ConvertTo-PrincipalActionCount -Events $arrEvents)

            # Assert
            $arrResult.Count | Should -Be 1
            $arrResult[0].PrincipalKey | Should -BeOfType [string]
            $arrResult[0].Action | Should -BeOfType [string]
            $arrResult[0].Count | Should -BeOfType [double]
        }
    }
}
