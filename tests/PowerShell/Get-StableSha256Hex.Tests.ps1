BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strSrcPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Get-StableSha256Hex.ps1')
}

Describe "Get-StableSha256Hex" {
    Context "When computing a hash" {
        It "Returns a 64-character lowercase hexadecimal string" {
            # Arrange
            $strInputString = 'user@example.com'
            $strSalt = 'test-salt'

            # Act
            $strResult = Get-StableSha256Hex -InputString $strInputString -Salt $strSalt

            # Assert
            $strResult | Should -Match '^[0-9a-f]{64}$'
        }

        It "Returns the same hash for identical inputs (deterministic)" {
            # Arrange
            $strInputString = 'alice'
            $strSalt = 'mySalt'

            # Act
            $strHash1 = Get-StableSha256Hex -InputString $strInputString -Salt $strSalt
            $strHash2 = Get-StableSha256Hex -InputString $strInputString -Salt $strSalt

            # Assert
            $strHash1 | Should -Be $strHash2
        }

        It "Returns different hashes for different input strings" {
            # Arrange
            $strSalt = 'shared-salt'

            # Act
            $strHash1 = Get-StableSha256Hex -InputString 'alice' -Salt $strSalt
            $strHash2 = Get-StableSha256Hex -InputString 'bob' -Salt $strSalt

            # Assert
            $strHash1 | Should -Not -Be $strHash2
        }

        It "Returns different hashes for different salt values" {
            # Arrange
            $strInputString = 'bob'

            # Act
            $strHash1 = Get-StableSha256Hex -InputString $strInputString -Salt 'salt-one'
            $strHash2 = Get-StableSha256Hex -InputString $strInputString -Salt 'salt-two'

            # Assert
            $strHash1 | Should -Not -Be $strHash2
        }

        It "Returns a value of type string" {
            # Arrange
            $strInputString = 'test-value'
            $strSalt = 'test-salt'

            # Act
            $strResult = Get-StableSha256Hex -InputString $strInputString -Salt $strSalt

            # Assert
            $strResult | Should -BeOfType [string]
        }
    }
}
