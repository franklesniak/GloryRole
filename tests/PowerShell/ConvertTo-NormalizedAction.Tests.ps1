BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strSrcPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'ConvertTo-NormalizedAction.ps1')
}

Describe "ConvertTo-NormalizedAction" {
    Context "When given a valid action string" {
        It "Returns lowercase trimmed action" {
            # Arrange
            $strInput = '  Microsoft.Compute/virtualMachines/Read  '

            # Act
            $strResult = ConvertTo-NormalizedAction -Action $strInput

            # Assert
            $strResult | Should -Be 'microsoft.compute/virtualmachines/read'
        }

        It "Handles already-lowercase input" {
            # Arrange
            $strInput = 'microsoft.storage/storageaccounts/write'

            # Act
            $strResult = ConvertTo-NormalizedAction -Action $strInput

            # Assert
            $strResult | Should -Be 'microsoft.storage/storageaccounts/write'
        }

        It "Preserves internal spaces while trimming and lowercasing" {
            # Arrange
            $strInput = '  Custom.Provider/resource type/Action  '

            # Act
            $strResult = ConvertTo-NormalizedAction -Action $strInput

            # Assert
            $strResult | Should -Be 'custom.provider/resource type/action'
        }
    }

    Context "When given null or whitespace input" {
        It "Returns null for null input" {
            # Act
            $strResult = ConvertTo-NormalizedAction -Action $null

            # Assert
            $strResult | Should -BeNullOrEmpty
        }

        It "Returns null for empty string" {
            # Act
            $strResult = ConvertTo-NormalizedAction -Action ''

            # Assert
            $strResult | Should -BeNullOrEmpty
        }

        It "Returns null for whitespace-only string" {
            # Act
            $strResult = ConvertTo-NormalizedAction -Action '   '

            # Assert
            $strResult | Should -BeNullOrEmpty
        }

        It "Returns null for tab-only whitespace input" {
            # Arrange
            $strInput = "`t`t"

            # Act
            $strResult = ConvertTo-NormalizedAction -Action $strInput

            # Assert
            $strResult | Should -BeNullOrEmpty
        }
    }
}
