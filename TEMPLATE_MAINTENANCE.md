# Template Maintenance Guide

This guide is for **maintainers of the `franklesniak/copilot-repo-template` repository**. It documents periodic maintenance tasks to keep the template current and functional.

> **Note:** If you created a repository FROM this template, see [OPTIONAL_CONFIGURATIONS.md](OPTIONAL_CONFIGURATIONS.md#ongoing-maintenance) for maintenance guidance relevant to your repository.

---

## Table of Contents

- [Recommended Review Cadence](#recommended-review-cadence)
- [Updating Pre-commit Hook Versions](#updating-pre-commit-hook-versions)
- [Reviewing Python Version Requirements](#reviewing-python-version-requirements)
- [Reviewing Terraform Version Requirements](#reviewing-terraform-version-requirements)
- [Reviewing Terraform Provider Versions](#reviewing-terraform-provider-versions)
- [Reviewing Instruction File Versions](#reviewing-instruction-file-versions)
- [Reviewing Agent Instruction Files](#reviewing-agent-instruction-files)
- [Testing Template Changes](#testing-template-changes)

---

## Recommended Review Cadence

To keep the template current and functional, maintainers **SHOULD** review template documentation and workflows on a **quarterly basis**.

**Quarterly Review Checklist:**

- [ ] Review and update pre-commit hook versions
- [ ] Check for updates to GitHub Actions used in workflows
- [ ] Review and update Terraform version in CI workflows
- [ ] Review instruction files for accuracy and relevance
- [ ] Verify all CI workflows still pass with latest dependency versions
- [ ] Verify agent instruction files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) are synchronized with `.github/copilot-instructions.md`
- [ ] Review and address any open issues or feedback

**Annual Review:**

- [ ] Review Python version requirements (typically October)
- [ ] Review major version updates for key dependencies (Node.js, Terraform providers, etc.)
- [ ] Evaluate new GitHub features that could enhance the template

> **Tip:** Set a calendar reminder for quarterly reviews to ensure consistent maintenance.

---

## Updating Pre-commit Hook Versions

Pre-commit hooks **SHOULD** be kept up-to-date for security and compatibility.

### Quick Update

```bash
# Check for and apply updates to pre-commit hooks
pre-commit autoupdate

# Test that updated hooks work correctly
pre-commit run --all-files
```

**Frequency:** Monthly or when security advisories are published for hook dependencies.

### Tools to Track

The following pre-commit hooks are configured in this template. Check their repositories for the latest releases:

| Tool | Repository | Purpose |
| --- | --- | --- |
| pre-commit-hooks | <https://github.com/pre-commit/pre-commit-hooks> | General file checks (trailing whitespace, YAML validation, etc.) |
| Black | <https://github.com/psf/black> | Python code formatting |
| Ruff | <https://github.com/astral-sh/ruff-pre-commit> | Python linting and formatting |
| markdownlint-cli2 | <https://github.com/DavidAnson/markdownlint-cli2> | Markdown linting |
| pre-commit-terraform | <https://github.com/antonbabenko/pre-commit-terraform> | Terraform formatting, validation, and linting |

### Files Requiring Manual Updates

After running `pre-commit autoupdate`, manually update version references in documentation files. The `pre-commit autoupdate` command only updates `.pre-commit-config.yaml`—version references in documentation examples require manual updates.

#### Black (Python formatter)

- `.pre-commit-config.yaml` (updated by `pre-commit autoupdate`)
- `OPTIONAL_CONFIGURATIONS.md` (Python pre-commit examples)
- `GETTING_STARTED_NEW_REPO.md` (commented example in pre-commit config)
- `GETTING_STARTED_EXISTING_REPO.md` (Python pre-commit examples)

#### Ruff (Python linter)

- `.pre-commit-config.yaml` (updated by `pre-commit autoupdate`)
- `OPTIONAL_CONFIGURATIONS.md` (Python pre-commit examples)
- `GETTING_STARTED_NEW_REPO.md` (commented example in pre-commit config)
- `GETTING_STARTED_EXISTING_REPO.md` (Python pre-commit examples)

#### pre-commit-terraform (Terraform hooks)

- `.pre-commit-config.yaml` (updated by `pre-commit autoupdate`)
- `.github/instructions/terraform.instructions.md` (pre-commit configuration examples)
- `docs/terraform/TERRAFORM_LINTING_GUIDE.md` (pre-commit configuration examples)
- `docs/terraform/TERRAFORM_COPILOT_INSTRUCTIONS_GUIDE.md` (pre-commit configuration examples)
- `docs/terraform/TERRAFORM_TESTING_GUIDE.md` (pre-commit configuration examples)

#### Other Hooks (no documentation references)

The following hooks are only referenced in `.pre-commit-config.yaml` and do not require manual documentation updates:

- pre-commit-hooks
- markdownlint-cli2

### Verification

After updating versions, use these commands to search for potentially stale version references:

```bash
# Check for Black version references (update the version number as appropriate)
grep -rn "rev:.*26\.1\.0" --include="*.md" --include="*.yaml" .

# Check for Ruff version references (update the version number as appropriate)
grep -rn "rev:.*v0\.14\.14" --include="*.md" --include="*.yaml" .

# Check for pre-commit-terraform version references (update the version number as appropriate)
grep -rn "rev:.*v1\.105\.0" --include="*.md" --include="*.yaml" .

# Generic search for any rev: patterns with version numbers
grep -rn "rev:.*v\?[0-9]\+\.[0-9]\+\.[0-9]\+" --include="*.md" --include="*.yaml" .
```

### Breaking Change Considerations

When updating to new major versions, check the release notes for breaking changes:

- **pre-commit-hooks:** May remove deprecated hooks or change Python version requirements. Review [pre-commit-hooks releases](https://github.com/pre-commit/pre-commit-hooks/releases).

- **Black:** Major releases may introduce style changes that reformat existing code differently. Review [Black changelog](https://github.com/psf/black/blob/main/CHANGES.md). Consider running `black --check` on a representative codebase before upgrading.

- **Ruff:** Frequently adds new rules that may flag previously-passing code. Review [Ruff changelog](https://github.com/astral-sh/ruff/blob/main/CHANGELOG.md). New rules are typically disabled by default, but rule behavior changes can affect existing configurations.

- **pre-commit-terraform:** May change hook IDs, arguments, or tool dependencies. Review [pre-commit-terraform releases](https://github.com/antonbabenko/pre-commit-terraform/releases). Ensure any referenced external tools (terraform, tflint, etc.) remain compatible.

---

## Reviewing Python Version Requirements

This template requires Python versions that are currently receiving bugfix updates from the Python core team.

**When to review:** Annually, typically around October when new Python versions are released.

**What to check:**

1. Visit the [Python Developer's Guide - Versions](https://devguide.python.org/versions/) page
2. Identify which versions are in "bugfix" status (not "security" or "end-of-life")
3. Update the following files if the minimum supported version changes:
   - `.github/workflows/python-ci.yml` (Python version matrix)
   - `pyproject.toml` (requires-python field)
   - `templates/python/pyproject.toml` (requires-python field)
   - `.github/instructions/python.instructions.md` (version references)

---

## Reviewing Terraform Version Requirements

This template uses a pinned Terraform version in CI workflows for reproducibility and pre-commit hook execution.

**When to review:** Quarterly, or when a new stable Terraform release is available.

**What to check:**

1. Visit the [Terraform Releases](https://releases.hashicorp.com/terraform/) page or the [Terraform GitHub Releases](https://github.com/hashicorp/terraform/releases)
2. Identify the latest stable release (avoid alpha, beta, or RC versions)
3. Update the Terraform version in the following workflow files:
   - `.github/workflows/terraform-ci.yml` (format, validate, and test jobs)
   - `.github/workflows/python-ci.yml` (pre-commit job)
   - `.github/workflows/auto-fix-precommit.yml` (auto-fix job)

**Version considerations:**

- **Pre-commit workflows:** Use the latest stable version for pre-commit hooks (terraform_fmt, terraform_validate, terraform_tflint)
- **Terraform CI tests:** The test framework requires Terraform 1.6.0+ and mock_provider requires 1.7.0+. The latest stable version satisfies both requirements.
- **Documentation:** After updating, verify that examples in documentation under `docs/terraform/` remain accurate. Note that these are illustrative examples and do not need to be updated unless the version syntax changes.

---

## Reviewing Terraform Provider Versions

The Terraform instructions file uses the newest stable major versions in provider version constraint examples. These should be reviewed periodically to ensure examples reflect current best practices.

**When to review:** Quarterly, or when a new major version of a provider becomes the recommended stable release.

**What to check:**

1. Visit the provider registries:
   - [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
   - [Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
   - [GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest)
2. Identify current stable major versions for each provider
3. If a new major version is now the recommended stable release, update the following files:
   - `.github/instructions/terraform.instructions.md` (version constraint examples throughout)
   - `.github/DESIGN_DECISIONS.md` (current versions table in "Current Provider Versions in Terraform Examples" section)

**Current versions (as of last update):**

| Provider | Example Constraint | Current Stable |
| --- | --- | --- |
| AWS | `~> 6.0` | 6.31.0 |
| Azure | `~> 4.0` | 4.58.0 |
| GCP | `~> 7.0` | 7.18.0 |

**How to update:**

When updating provider versions in terraform.instructions.md, search for the version constraint patterns:

```bash
# Search for AWS provider version references
grep -n "~> 5\.0\|~> 6\.0" .github/instructions/terraform.instructions.md

# Search for Azure provider version references
grep -n "~> 3\.0\|~> 4\.0" .github/instructions/terraform.instructions.md

# Search for GCP provider version references
grep -n "~> 6\.0\|~> 7\.0" .github/instructions/terraform.instructions.md
```

Update all occurrences to the new major version constraint (e.g., `~> 6.0` to `~> 7.0`).

---

## Reviewing Instruction File Versions

The instruction files in `.github/instructions/` include version numbers in the format `Major.Minor.YYYYMMDD.Revision`.

**When to update:**

- Major version: Breaking changes to coding standards
- Minor version: New guidance or significant clarifications
- Date/Revision: Bug fixes or minor wording changes

**Files to review:**

- `.github/instructions/docs.instructions.md`
- `.github/instructions/python.instructions.md`
- `.github/instructions/powershell.instructions.md`
- `.github/instructions/terraform.instructions.md`

---

## Reviewing Agent Instruction Files

Agent instruction files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) **MUST** be kept synchronized with `.github/copilot-instructions.md`. These files contain inline summaries of the canonical rules so that each AI coding agent receives project-specific guidance without needing to follow file references.

**What to check during review:**

- Safety rules match between `.github/copilot-instructions.md` and all three agent files
- Pre-commit discipline requirements match
- Build/test commands match (including any new tools or changed commands)
- Language-specific instruction file references match (if instruction files are added/removed/renamed)
- "What Not to Do" rules match

**Verification command:**

```bash
# Compare recent commit history to identify unsynchronized changes
# If copilot-instructions.md was modified more recently than agent files,
# manually verify agent files still match
git log --oneline -5 .github/copilot-instructions.md
git log --oneline -5 CLAUDE.md AGENTS.md GEMINI.md
```

**When to update:** Whenever `.github/copilot-instructions.md` is modified, or when new agent platforms emerge that require their own convention files.

---

## Testing Template Changes

Before merging significant template changes:

1. Create a test repository from the template
2. Complete the setup process following `GETTING_STARTED_NEW_REPO.md`
3. Verify all CI workflows pass
4. Test the placeholder check workflow triggers and passes after placeholder replacement
5. Verify issue templates render correctly
6. Open and close a test PR to verify the PR template

Delete the test repository after verification.
