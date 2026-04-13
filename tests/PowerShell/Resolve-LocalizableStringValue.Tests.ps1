BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strRepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $strRepoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Resolve-LocalizableStringValue.ps1')
}

Describe "Resolve-LocalizableStringValue" {
    Context "When the input is null" {
        It "Returns null" {
            # Arrange, Act
            $strResult = Resolve-LocalizableStringValue -InputObject $null

            # Assert
            $strResult | Should -Be $null
        }
    }

    Context "When the input is a plain string (Az.Monitor 7+ shape)" {
        It "Returns the string unchanged" {
            # Arrange
            $strInput = 'Succeeded'

            # Act
            $strResult = Resolve-LocalizableStringValue -InputObject $strInput

            # Assert
            $strResult | Should -Be 'Succeeded'
        }

        It "Returns an empty string as-is (distinguishable from null)" {
            # Arrange, Act
            $strResult = Resolve-LocalizableStringValue -InputObject ''

            # Assert
            $strResult | Should -Be ''
            $strResult | Should -Not -Be $null
        }
    }

    Context "When the input is a PSObject with Value (legacy Az.Monitor shape)" {
        It "Returns the Value property" {
            # Arrange
            $objInput = [pscustomobject]@{
                Value = 'Succeeded'
                LocalizedValue = 'Succeeded (localized)'
            }

            # Act
            $strResult = Resolve-LocalizableStringValue -InputObject $objInput

            # Assert
            # Value is preferred over LocalizedValue because Value holds
            # the non-localized canonical form used by downstream logic.
            $strResult | Should -Be 'Succeeded'
        }
    }

    Context "When the input is a PSObject with only LocalizedValue" {
        It "Falls back to LocalizedValue" {
            # Arrange
            $objInput = [pscustomobject]@{ LocalizedValue = 'Administrative' }

            # Act
            $strResult = Resolve-LocalizableStringValue -InputObject $objInput

            # Assert
            $strResult | Should -Be 'Administrative'
        }
    }

    Context "When the input is a PSObject whose Value is null" {
        It "Returns null rather than the empty string from a null cast" {
            # Arrange
            $objInput = [pscustomobject]@{ Value = $null }

            # Act
            $strResult = Resolve-LocalizableStringValue -InputObject $objInput

            # Assert
            $strResult | Should -Be $null
        }
    }

    Context "When the input is a PSObject with neither Value nor LocalizedValue" {
        It "Returns null" {
            # Arrange
            $objInput = [pscustomobject]@{ Other = 'irrelevant' }

            # Act
            $strResult = Resolve-LocalizableStringValue -InputObject $objInput

            # Assert
            $strResult | Should -Be $null
        }
    }

    Context "When the input is a value type without PSObject properties" {
        It "Returns null for an integer" {
            # Arrange, Act
            $strResult = Resolve-LocalizableStringValue -InputObject 42

            # Assert
            $strResult | Should -Be $null
        }
    }
}
