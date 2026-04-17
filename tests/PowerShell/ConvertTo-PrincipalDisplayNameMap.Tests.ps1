BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'

    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-PrincipalDisplayNameMap.ps1')
}

Describe "ConvertTo-PrincipalDisplayNameMap" {
    Context "When given an empty event array" {
        It "Returns an empty hashtable" {
            # Arrange / Act
            $hashResult = ConvertTo-PrincipalDisplayNameMap -Events @()

            # Assert
            $hashResult | Should -BeOfType [hashtable]
            $hashResult.Count | Should -Be 0
        }
    }

    Context "When given events with PrincipalUPN populated" {
        It "Maps each PrincipalKey to its UPN" {
            # Arrange
            $arrEvents = @(
                [pscustomobject]@{
                    PrincipalKey = '11111111-1111-1111-1111-111111111111'
                    PrincipalUPN = 'alice@contoso.com'
                }
                [pscustomobject]@{
                    PrincipalKey = '22222222-2222-2222-2222-222222222222'
                    PrincipalUPN = 'bob@contoso.com'
                }
            )

            # Act
            $hashResult = ConvertTo-PrincipalDisplayNameMap -Events $arrEvents

            # Assert
            $hashResult.Count | Should -Be 2
            $hashResult['11111111-1111-1111-1111-111111111111'] | Should -Be 'alice@contoso.com'
            $hashResult['22222222-2222-2222-2222-222222222222'] | Should -Be 'bob@contoso.com'
        }
    }

    Context "When PrincipalUPN is missing or whitespace" {
        It "Falls back to PrincipalKey when PrincipalUPN is null" {
            # Arrange
            $arrEvents = @(
                [pscustomobject]@{
                    PrincipalKey = '33333333-3333-3333-3333-333333333333'
                    PrincipalUPN = $null
                }
            )

            # Act
            $hashResult = ConvertTo-PrincipalDisplayNameMap -Events $arrEvents

            # Assert
            $hashResult.Count | Should -Be 1
            $hashResult['33333333-3333-3333-3333-333333333333'] | Should -Be '33333333-3333-3333-3333-333333333333'
        }

        It "Falls back to PrincipalKey when PrincipalUPN is empty string" {
            # Arrange
            $arrEvents = @(
                [pscustomobject]@{
                    PrincipalKey = '44444444-4444-4444-4444-444444444444'
                    PrincipalUPN = ''
                }
            )

            # Act
            $hashResult = ConvertTo-PrincipalDisplayNameMap -Events $arrEvents

            # Assert
            $hashResult.Count | Should -Be 1
            $hashResult['44444444-4444-4444-4444-444444444444'] | Should -Be '44444444-4444-4444-4444-444444444444'
        }

        It "Falls back to PrincipalKey when PrincipalUPN is whitespace" {
            # Arrange
            $arrEvents = @(
                [pscustomobject]@{
                    PrincipalKey = '55555555-5555-5555-5555-555555555555'
                    PrincipalUPN = "   `t  "
                }
            )

            # Act
            $hashResult = ConvertTo-PrincipalDisplayNameMap -Events $arrEvents

            # Assert
            $hashResult.Count | Should -Be 1
            $hashResult['55555555-5555-5555-5555-555555555555'] | Should -Be '55555555-5555-5555-5555-555555555555'
        }
    }

    Context "When the same PrincipalKey appears multiple times" {
        It "Honors first-write-wins for the UPN value" {
            # Arrange
            $arrEvents = @(
                [pscustomobject]@{
                    PrincipalKey = '66666666-6666-6666-6666-666666666666'
                    PrincipalUPN = 'first@contoso.com'
                }
                [pscustomobject]@{
                    PrincipalKey = '66666666-6666-6666-6666-666666666666'
                    PrincipalUPN = 'second@contoso.com'
                }
            )

            # Act
            $hashResult = ConvertTo-PrincipalDisplayNameMap -Events $arrEvents

            # Assert
            $hashResult.Count | Should -Be 1
            $hashResult['66666666-6666-6666-6666-666666666666'] | Should -Be 'first@contoso.com'
        }

        It "Does not upgrade a PrincipalKey fallback when a later event has a UPN" {
            # Arrange -- first event has no UPN (sets fallback), second event
            # for the same key has a UPN; first-write-wins keeps the fallback.
            $arrEvents = @(
                [pscustomobject]@{
                    PrincipalKey = '77777777-7777-7777-7777-777777777777'
                    PrincipalUPN = $null
                }
                [pscustomobject]@{
                    PrincipalKey = '77777777-7777-7777-7777-777777777777'
                    PrincipalUPN = 'late@contoso.com'
                }
            )

            # Act
            $hashResult = ConvertTo-PrincipalDisplayNameMap -Events $arrEvents

            # Assert
            $hashResult.Count | Should -Be 1
            $hashResult['77777777-7777-7777-7777-777777777777'] | Should -Be '77777777-7777-7777-7777-777777777777'
        }
    }

    Context "When given a mix of user and application principals" {
        It "Resolves UPNs for users and falls back to PrincipalKey for apps" {
            # Arrange
            $arrEvents = @(
                [pscustomobject]@{
                    PrincipalKey = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                    PrincipalUPN = 'alice@contoso.com'
                }
                [pscustomobject]@{
                    PrincipalKey = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
                    PrincipalUPN = ''
                }
                [pscustomobject]@{
                    PrincipalKey = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
                    PrincipalUPN = 'carol@contoso.com'
                }
            )

            # Act
            $hashResult = ConvertTo-PrincipalDisplayNameMap -Events $arrEvents

            # Assert
            $hashResult.Count | Should -Be 3
            $hashResult['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'] | Should -Be 'alice@contoso.com'
            $hashResult['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'] | Should -Be 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            $hashResult['cccccccc-cccc-cccc-cccc-cccccccccccc'] | Should -Be 'carol@contoso.com'
        }
    }
}
