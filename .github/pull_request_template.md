## Description

<!-- Provide a brief description of the changes in this PR -->

## Type of Change

<!-- Check all that apply -->

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Dependencies update
- [ ] Configuration/tooling change

## Checklist

<!-- Review and check all items before submitting -->

### General

- [ ] I have read the [contributing guidelines](../blob/HEAD/CONTRIBUTING.md)
- [ ] My code follows the coding standards in `.github/instructions/`
- [ ] My changes follow `.github/copilot-instructions.md` and any applicable `.github/instructions/*`
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code where necessary, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added or updated tests where appropriate
- [ ] New and existing tests pass locally (where applicable)

### Pre-commit Verification

- [ ] I have run `pre-commit run --all-files` locally and all checks pass
- [ ] I have reviewed and committed all auto-fixes made by pre-commit hooks

### PowerShell-Specific (if applicable)

<!-- Delete this section if your changes do not include PowerShell -->

- [ ] PSScriptAnalyzer passes locally (`Invoke-ScriptAnalyzer -Path . -Settings .github/linting/PSScriptAnalyzerSettings.psd1`)
- [ ] Pester tests pass locally (`Invoke-Pester -Path tests/ -Output Detailed`)
- [ ] PowerShell formatting follows repository standards (OTBS, consistent line endings)

## Additional Notes

<!-- Add any additional information that reviewers should know -->

## Related Issues

<!-- Link any related issues using #issue_number -->

Closes #
