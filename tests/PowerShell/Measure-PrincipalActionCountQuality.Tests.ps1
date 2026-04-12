BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Measure-PrincipalActionCountQuality.ps1')
}

Describe "Measure-PrincipalActionCountQuality" {
    Context "When given valid counts" {
        It "Computes distinct principal, action, and non-zero entry counts" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'read'; Count = 5.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'write'; Count = 3.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'read'; Count = 7.0 }
            )

            # Act
            $objResult = Measure-PrincipalActionCountQuality -Counts $arrCounts

            # Assert
            $objResult.Principals | Should -Be 2
            $objResult.Actions | Should -Be 2
            $objResult.NonZeroEntries | Should -Be 3
        }

        It "Computes density as non-zero entries divided by principals times actions" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'read'; Count = 5.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'write'; Count = 3.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'read'; Count = 7.0 }
            )

            # Act
            $objResult = Measure-PrincipalActionCountQuality -Counts $arrCounts

            # Assert
            # Density = 3 / (2 * 2) = 0.75
            $objResult.Density | Should -Be 0.75
        }
    }

    Context "When inspecting Top-N results" {
        It "Sorts TopActions and TopPrincipals by descending count" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'read'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u2'; Action = 'read'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u3'; Action = 'read'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'write'; Count = 1.0 }
            )

            # Act
            $objResult = Measure-PrincipalActionCountQuality -Counts $arrCounts

            # Assert
            $objResult.TopActions[0].Name | Should -Be 'read'
            $objResult.TopActions[0].Count | Should -Be 3
            $objResult.TopPrincipals[0].Name | Should -Be 'u1'
            $objResult.TopPrincipals[0].Count | Should -Be 2
        }

        It "Limits TopActions to at most 10 entries" {
            # Arrange - create 12 distinct actions
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-01'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-02'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-03'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-04'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-05'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-06'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-07'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-08'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-09'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-10'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-11'; Count = 1.0 }
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'action-12'; Count = 1.0 }
            )

            # Act
            $objResult = Measure-PrincipalActionCountQuality -Counts $arrCounts

            # Assert
            $objResult.TopActions.Count | Should -Be 10
        }
    }

    Context "When verifying return type" {
        It "Returns a pscustomobject" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'read'; Count = 1.0 }
            )

            # Act
            $objResult = Measure-PrincipalActionCountQuality -Counts $arrCounts

            # Assert
            $objResult | Should -BeOfType [pscustomobject]
        }
    }

    Context "When given edge-case input" {
        It "Returns density of 1.0 for a single sparse triple" {
            # Arrange
            $arrCounts = @(
                [pscustomobject]@{ PrincipalKey = 'u1'; Action = 'only-action'; Count = 1.0 }
            )

            # Act
            $objResult = Measure-PrincipalActionCountQuality -Counts $arrCounts

            # Assert
            $objResult.Density | Should -Be 1.0
            $objResult.Principals | Should -Be 1
            $objResult.Actions | Should -Be 1
            $objResult.NonZeroEntries | Should -Be 1
        }
    }
}
