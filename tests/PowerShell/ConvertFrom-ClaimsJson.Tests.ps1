BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strSrcPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertFrom-ClaimsJson.ps1')
}

Describe "ConvertFrom-ClaimsJson" {
    Context "When given a valid JSON string" {
        It "Returns a parsed object with expected properties" {
            # Arrange
            $strInput = '{"appid":"abc-123"}'

            # Act
            $objResult = ConvertFrom-ClaimsJson -Claims $strInput

            # Assert
            $objResult.appid | Should -Be 'abc-123'
        }

        It "Trims surrounding whitespace before parsing" {
            # Arrange
            $strInput = '  {"appid":"trimmed"}  '

            # Act
            $objResult = ConvertFrom-ClaimsJson -Claims $strInput

            # Assert
            $objResult.appid | Should -Be 'trimmed'
        }
    }

    Context "When given null input" {
        It "Returns null for null input" {
            # Act
            $objResult = ConvertFrom-ClaimsJson -Claims $null

            # Assert
            $objResult | Should -Be $null
        }
    }

    Context "When given an already-parsed object" {
        It "Returns the exact same object instance" {
            # Arrange
            $objInput = [pscustomobject]@{ appid = 'existing' }

            # Act
            $objResult = ConvertFrom-ClaimsJson -Claims $objInput

            # Assert
            [object]::ReferenceEquals($objInput, $objResult) | Should -BeTrue
        }
    }

    Context "When given invalid or non-JSON input" {
        It "Returns null for malformed JSON" {
            # Arrange
            $strInput = '{not valid json}'

            # Act
            $objResult = ConvertFrom-ClaimsJson -Claims $strInput

            # Assert
            $objResult | Should -Be $null
        }

        It "Returns null for a non-JSON string" {
            # Arrange
            $strInput = 'just a plain string'

            # Act
            $objResult = ConvertFrom-ClaimsJson -Claims $strInput

            # Assert
            $objResult | Should -Be $null
        }

        It "Returns null for an empty string" {
            # Arrange
            $strInput = ''

            # Act
            $objResult = ConvertFrom-ClaimsJson -Claims $strInput

            # Assert
            $objResult | Should -Be $null
        }
    }
}
