# Validates that every fenced PowerShell code block embedded in designated
# analysis documents parses as syntactically valid PowerShell, so that edits to
# embedded scripts cannot silently introduce syntax errors that CI would
# otherwise never see (PSScriptAnalyzer and Pester only inspect .ps1 files).
#
# Documents are opted in explicitly by relative path. Some analysis artifacts
# (for example, the Azure RBAC vs. Entra ID parity gap analysis) quote
# deliberate code fragments such as parameter excerpts and elided branches that
# are not standalone-parseable; those documents must not be added to the
# opt-in list unless their fragments are made parseable first.

BeforeAll {
    # Avoid relative-path segments per style guide checklist item
    $strTestsRootDirectory = Split-Path -Path $PSScriptRoot -Parent
    $strRepositoryRootDirectory = Split-Path -Path $strTestsRootDirectory -Parent

    $arrParseValidatedDocumentRelativePath = @(
        'docs/analysis/2026-07-16-active-directory-domain-services-administrative-action-auditing.md'
    )

    $listEmbeddedCodeBlocks = New-Object System.Collections.Generic.List[pscustomobject]
    $listUnterminatedFenceDescriptions = New-Object System.Collections.Generic.List[string]

    foreach ($strDocumentRelativePath in $arrParseValidatedDocumentRelativePath) {
        $strDocumentPath = Join-Path -Path $strRepositoryRootDirectory -ChildPath $strDocumentRelativePath
        $arrDocumentLines = @(Get-Content -LiteralPath $strDocumentPath)

        $boolInsidePowerShellCodeBlock = $false
        $intCodeBlockStartLineNumber = 0
        $listCurrentCodeBlockLines = New-Object System.Collections.Generic.List[string]

        for ($intLineIndex = 0; $intLineIndex -lt $arrDocumentLines.Count; $intLineIndex++) {
            $strCurrentLine = $arrDocumentLines[$intLineIndex]

            if (-not $boolInsidePowerShellCodeBlock) {
                if ($strCurrentLine -ceq '```powershell') {
                    $boolInsidePowerShellCodeBlock = $true
                    $intCodeBlockStartLineNumber = $intLineIndex + 1
                    $listCurrentCodeBlockLines.Clear()
                }
            } else {
                if ($strCurrentLine -ceq '```') {
                    [void]($listEmbeddedCodeBlocks.Add([pscustomobject]@{
                                DocumentRelativePath = $strDocumentRelativePath
                                StartLineNumber = $intCodeBlockStartLineNumber
                                Content = ($listCurrentCodeBlockLines -join [System.Environment]::NewLine)
                            }))
                    $boolInsidePowerShellCodeBlock = $false
                } else {
                    [void]($listCurrentCodeBlockLines.Add($strCurrentLine))
                }
            }
        }

        if ($boolInsidePowerShellCodeBlock) {
            $strUnterminatedFenceDescription = (
                '{0}: the PowerShell code fence opened at line {1} is never closed' -f
                $strDocumentRelativePath,
                $intCodeBlockStartLineNumber
            )
            [void]($listUnterminatedFenceDescriptions.Add($strUnterminatedFenceDescription))
        }
    }
}

Describe "Embedded PowerShell code blocks in analysis documents" {
    Context "When extracting fenced PowerShell blocks from opted-in documents" {
        It "Discovers at least one embedded PowerShell code block" {
            # Assert
            $listEmbeddedCodeBlocks.Count | Should -BeGreaterThan 0
        }

        It "Closes every fenced PowerShell code block before the end of the document" {
            # Assert
            ($listUnterminatedFenceDescriptions -join [System.Environment]::NewLine) | Should -BeNullOrEmpty
        }

        It "Parses every embedded PowerShell code block without syntax errors" {
            # Arrange
            $listEmbeddedCodeBlocks.Count | Should -BeGreaterThan 0
            $listParseFailureDescriptions = New-Object System.Collections.Generic.List[string]

            # Act
            foreach ($objEmbeddedCodeBlock in $listEmbeddedCodeBlocks) {
                $arrParseTokens = $null
                $arrParseErrors = $null
                [void][System.Management.Automation.Language.Parser]::ParseInput(
                    $objEmbeddedCodeBlock.Content,
                    [ref]$arrParseTokens,
                    [ref]$arrParseErrors
                )

                if ($null -ne $arrParseErrors -and $arrParseErrors.Count -gt 0) {
                    foreach ($objParseError in $arrParseErrors) {
                        $strParseFailureDescription = (
                            '{0} (block starting at line {1}): {2}' -f
                            $objEmbeddedCodeBlock.DocumentRelativePath,
                            $objEmbeddedCodeBlock.StartLineNumber,
                            $objParseError.Message
                        )
                        [void]($listParseFailureDescriptions.Add($strParseFailureDescription))
                    }
                }
            }

            # Assert
            ($listParseFailureDescriptions -join [System.Environment]::NewLine) | Should -BeNullOrEmpty
        }
    }
}
