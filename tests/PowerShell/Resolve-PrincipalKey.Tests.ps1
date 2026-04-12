BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $strSrcPath = Join-Path -Path $repoRoot -ChildPath 'src'
    . (Join-Path -Path $strSrcPath -ChildPath 'Resolve-PrincipalKey.ps1')
}

Describe "Resolve-PrincipalKey" {
    Context "When ObjectId is provided" {
        It "Returns ObjectId as Key with type User" {
            # Arrange / Act
            $objResult = Resolve-PrincipalKey -ObjectId 'oid-123' -AppId 'app-456' -Caller 'user@example.com'

            # Assert
            $objResult.Key | Should -Be 'oid-123'
            $objResult.Type | Should -Be 'User'
        }
    }

    Context "When only AppId is provided" {
        It "Returns AppId as Key with type ServicePrincipal" {
            # Arrange / Act
            $objResult = Resolve-PrincipalKey -ObjectId '' -AppId 'app-456' -Caller 'user@example.com'

            # Assert
            $objResult.Key | Should -Be 'app-456'
            $objResult.Type | Should -Be 'ServicePrincipal'
        }
    }

    Context "When only Caller is provided" {
        It "Returns Caller as Key with type Unknown" {
            # Arrange / Act
            $objResult = Resolve-PrincipalKey -ObjectId '' -AppId '' -Caller 'user@example.com'

            # Assert
            $objResult.Key | Should -Be 'user@example.com'
            $objResult.Type | Should -Be 'Unknown'
        }
    }

    Context "When no identity fields are provided" {
        It "Returns null" {
            # Arrange / Act
            $objResult = Resolve-PrincipalKey -ObjectId '' -AppId '' -Caller ''

            # Assert
            $objResult | Should -BeNullOrEmpty
        }
    }

    Context "When precedence is tested" {
        It "Prefers ObjectId over AppId and Caller" {
            # Act
            $objResult = Resolve-PrincipalKey -ObjectId 'oid' -AppId 'app' -Caller 'caller'

            # Assert
            $objResult.Key | Should -Be 'oid'
        }

        It "Prefers AppId over Caller when ObjectId is empty" {
            # Act
            $objResult = Resolve-PrincipalKey -ObjectId '' -AppId 'app' -Caller 'caller'

            # Assert
            $objResult.Key | Should -Be 'app'
        }
    }

    Context "When inputs are whitespace-only" {
        It "Returns null when all fields are whitespace" {
            # Arrange / Act
            $objResult = Resolve-PrincipalKey -ObjectId '   ' -AppId '  ' -Caller ' '

            # Assert
            $objResult | Should -BeNullOrEmpty
        }
    }

    Context "When no arguments are provided" {
        It "Returns null when parameters are not supplied" {
            # Arrange / Act
            $objResult = Resolve-PrincipalKey

            # Assert
            $objResult | Should -BeNullOrEmpty
        }
    }

    Context "When verifying output structure" {
        It "Returns a pscustomobject with exactly Key and Type properties" {
            # Arrange / Act
            $objResult = Resolve-PrincipalKey -ObjectId 'oid-123' -AppId '' -Caller ''

            # Assert
            $objResult | Should -Not -BeNullOrEmpty
            $objResult -is [pscustomobject] | Should -BeTrue
            $arrPropertyNames = $objResult.PSObject.Properties.Name
            $arrPropertyNames | Should -HaveCount 2
            $arrPropertyNames | Should -Contain 'Key'
            $arrPropertyNames | Should -Contain 'Type'
        }
    }
}
