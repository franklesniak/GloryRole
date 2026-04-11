BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strSrcPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'New-FeatureIndex.ps1')
}

Describe "New-FeatureIndex" {
    Context "When given valid counts" {
        It "Creates a sorted feature index" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'zebra/read'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'alpha/write'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'middle/delete'; Count = 1.0 }
            )

            # Act
            $objResult = New-FeatureIndex -PrincipalActionCounts $arrCounts

            # Assert
            $objResult.FeatureNames.Count | Should -Be 3
            $objResult.FeatureNames[0] | Should -Be 'alpha/write'
            $objResult.FeatureNames[1] | Should -Be 'middle/delete'
            $objResult.FeatureNames[2] | Should -Be 'zebra/read'
        }

        It "Maps actions to sequential indices" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'b'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'a'; Count = 1.0 }
            )

            # Act
            $objResult = New-FeatureIndex -PrincipalActionCounts $arrCounts

            # Assert
            $objResult.FeatureIndex['a'] | Should -Be 0
            $objResult.FeatureIndex['b'] | Should -Be 1
        }

        It "Deduplicates actions across principals" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'shared'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'shared'; Count = 1.0 }
            )

            # Act
            $objResult = New-FeatureIndex -PrincipalActionCounts $arrCounts

            # Assert
            $objResult.FeatureNames.Count | Should -Be 1
        }
    }

    Context "When given edge-case input" {
        It "Handles single-element input" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'only/action'; Count = 1.0 }
            )

            # Act
            $objResult = New-FeatureIndex -PrincipalActionCounts $arrCounts

            # Assert
            $objResult.FeatureNames.Count | Should -Be 1
            $objResult.FeatureIndex['only/action'] | Should -Be 0
        }

        It "Deduplicates all-identical actions to a single feature" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'same/action'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'same/action'; Count = 2.0 }
                [pscustomobject]@{ PrincipalKey = 'u3'; Action = 'same/action'; Count = 3.0 }
            )

            # Act
            $objResult = New-FeatureIndex -PrincipalActionCounts $arrCounts

            # Assert
            $objResult.FeatureNames.Count | Should -Be 1
        }
    }
}
