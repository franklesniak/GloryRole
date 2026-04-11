# Contributing to This Project

<!--
TEMPLATE DESIGN DECISION: Placeholder Strategy

This file uses OWNER/REPO placeholders (not generic <your-repo> syntax) because:
- Enables bulk find-and-replace for template adopters (single operation)
- CI automation can verify all placeholders are replaced (.github/workflows/check-placeholders.yml)
- Results in working, copy-pastable commands after replacement
- Consistent with issue templates and other template files

Alternative considered: Generic angle-bracket syntax like <your-repository-clone-url>
Rejected because: Harder to replace in bulk, produces non-working commands,
inconsistent with other files that require real values (CI configs, package.json)

See README.md Template Setup Checklist for adoption instructions.
See OPTIONAL_CONFIGURATIONS.md for detailed customization guidance.
-->

Thank you for your interest in contributing! This document provides guidelines for contributing to this repository.

## Python Version Requirements

**Important:** Contributors and maintainers must use a Python version that is **currently receiving bugfixes** from the Python core team.

### Why This Matters

- Python versions in "security fix only" phase are **not publicly installable** with security updates—they require building from source with manually applied patches
- This policy ensures all contributors can install and use the same Python version with current security updates
- It maintains consistency across development environments and CI

### Current Requirements

This project requires a Python version that is currently in "bugfix" status according to the Python core team.

See the [Python Developer's Guide - Versions](https://devguide.python.org/versions/) page for current version status.

> **Template adopters:** Customize this section based on your project's specific Python version requirements. You may specify a minimum version (e.g., "Python 3.11+") or reference your project's own support policy.

### When to Update

Check the [Python Developer's Guide - Versions](https://devguide.python.org/versions/) page annually (typically around October when new Python versions are released). Update the minimum required version when upstream support changes.

**Do not default to or require unsupported Python versions in code, documentation, or configuration files.**

## Development Setup

### 1. Clone the Repository

<!-- CUSTOMIZE: Replace `OWNER/REPO` with your organization and repository name -->

```bash
git clone https://github.com/OWNER/REPO.git
cd REPO
```

### 2. Install Node.js Dependencies (for Markdown linting)

```bash
npm install
```

This installs Node.js dependencies for markdown linting scripts. Git hooks are managed by pre-commit (see step 4 below).

### Git Hooks

This repository uses pre-commit for git hooks. Configured hooks include:

- **Formatting**: Black (Python), trailing whitespace, end-of-file fixer
- **Linting**: Ruff (Python), markdownlint (Markdown), YAML validation
- **Safety**: Large file detection

If you need to bypass hooks temporarily (not recommended):

```bash
git commit --no-verify -m "your message"
```

### Markdown Linting

Run markdown linting manually:

```bash
npm run lint:md           # Lint all markdown files
npm run lint:md:nested    # Lint nested markdown blocks in docs
```

### 3. Install Python (if working with Python code)

Ensure you have a Python version that is currently receiving bugfixes (see [Python Version Requirements](#python-version-requirements) above):

```bash
python --version  # Should be a version currently receiving bugfixes
```

### 4. Install pre-commit (Globally)

**Important:** `pre-commit` is intentionally **NOT** included as a project dev dependency. Install it globally:

#### Option 1: Using pip (recommended for most users)

```bash
pip install pre-commit
```

#### Option 2: Using pipx (recommended for tool isolation)

```bash
pipx install pre-commit
```

#### Why Not a Dev Dependency?

- `pre-commit` is a **development tool**, not a project runtime or test dependency
- It manages its own isolated environments for hooks (including Python tools like Black and Ruff)
- Installing it globally or via `pipx` keeps it separate from project dependencies
- This is the standard practice in the Python community
- CI workflows install `pre-commit` separately in their own steps

### 5. Install Pre-commit Hooks

After installing `pre-commit` globally, set up the hooks in your local repository:

```bash
pre-commit install
```

This configures Git to automatically run pre-commit hooks before each commit.

### 6. Run Pre-commit Manually

To run all pre-commit hooks on all files (recommended before submitting a PR):

```bash
pre-commit run --all-files
```

To run pre-commit on staged files only:

```bash
pre-commit run
```

## Code Quality Standards

### Pre-commit Discipline

**⚠️ CRITICAL: Always run pre-commit checks before committing code.**

Pre-commit hooks are NOT optional. They enforce:

- Code formatting (Black for Python, Prettier/markdownlint for Markdown)
- Linting (Ruff for Python)
- Trailing whitespace removal
- End-of-file fixes
- YAML validation

See `.pre-commit-config.yaml` for the complete list of configured hooks.

**Workflow:**

1. Make your code changes
2. Run `pre-commit run --all-files`
3. Review and commit ALL auto-fixes as part of your change
4. Push to GitHub

**If pre-commit CI fails:**

1. Pull the latest branch
2. Run `pre-commit run --all-files` locally
3. Commit the fixes with message "Apply pre-commit auto-fixes"
4. Push again

**CI is a safety net, not a substitute for local checks.**

### Language-Specific Guidelines

This repository includes comprehensive coding standards for multiple languages:

- **Python:** `.github/instructions/python.instructions.md`
- **PowerShell:** `.github/instructions/powershell.instructions.md`
- **Markdown/Documentation:** `.github/instructions/docs.instructions.md`

These standards are enforced by GitHub Copilot and should be followed for all contributions.

### CI Workflows

This repository includes several GitHub Actions workflows that run automatically:

| Workflow | File | Purpose |
| --- | --- | --- |
| Python CI | `.github/workflows/python-ci.yml` | Runs pre-commit, mypy (type checking), and pytest on Python files |
| Auto-fix Pre-commit | `.github/workflows/auto-fix-precommit.yml` | Automatically commits pre-commit fixes on PRs (optional) |
| Markdown Lint | `.github/workflows/markdownlint.yml` | Validates markdown formatting |
| PowerShell CI | `.github/workflows/powershell-ci.yml` | Runs PSScriptAnalyzer on PowerShell files |

The **Auto-fix Pre-commit** workflow is particularly useful for AI-assisted development (e.g., GitHub Copilot Coding Agent) as it automatically commits formatting fixes to PR branches.

## Making Changes

### 1. Create a Branch

```bash
git checkout -b your-feature-branch
```

### 2. Make Your Changes

Follow the coding standards for the language(s) you're working with.

### 3. Run Pre-commit Hooks

```bash
pre-commit run --all-files
```

Fix any issues that are reported.

### 4. Run Tests

Before submitting a pull request, ensure all tests pass locally.

#### Python Tests

```bash
# Install dev dependencies
pip install -e ".[dev]"

# Run tests with coverage
pytest tests/ -v --cov --cov-report=term-missing

# Run type checks
mypy src/ tests/
```

#### PowerShell Tests

```powershell
# Install Pester if not already installed
Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser

# Run all Pester tests
Invoke-Pester -Path tests/ -Output Detailed
```

#### Test Requirements

- **Python:** New functionality should include pytest tests in `tests/`
- **PowerShell:** New functions should include Pester tests in `tests/PowerShell/`
- All tests must pass on the CI matrix (Ubuntu, Windows, macOS)

### 5. Commit Your Changes

```bash
git add .
git commit -m "Your descriptive commit message"
```

Pre-commit hooks will run automatically. If they make changes, review them and commit again.

### 6. Push Your Branch

```bash
git push origin your-feature-branch
```

### 7. Open a Pull Request

Open a PR on GitHub and fill out the PR template checklist.

## Pull Request Guidelines

When submitting a pull request:

- [ ] Confirm minimum Python version (if applicable) complies with bugfix support policy
- [ ] Confirm `pre-commit run --all-files` passes locally
- [ ] Include tests for new functionality
- [ ] Update documentation as needed
- [ ] Ensure all CI checks pass

## Questions or Issues?

If you have questions or encounter issues:

<!-- CUSTOMIZE: Replace `OWNER/REPO` with your organization and repository name -->

1. Check existing [Issues](https://github.com/OWNER/REPO/issues)
2. Review the documentation in `.github/instructions/`
3. Open a new issue with a clear description of the problem

## License

<!--
TEMPLATE ADOPTERS: Update this section if your project uses a license other than MIT.

If using a different open source license (Apache 2.0, GPL, BSD, etc.):
- Replace "MIT License" with your license name
- Ensure consistency with the LICENSE file in the repository root

If using a proprietary license:
- Replace the entire contribution agreement text below
- Consider adding Contributor License Agreement (CLA) requirements
- Consult with legal counsel for appropriate contribution terms

See OPTIONAL_CONFIGURATIONS.md "License Customization" section for detailed guidance.
-->

By contributing to this project, you agree that your contributions will be licensed under the same license as the project (MIT License).

## For Template Users

<!--
TEMPLATE ADOPTERS: This entire section is meta-documentation about the template itself.
After you've reviewed and understood this content, you should:
- Option A: Remove this entire section (recommended for most downstream projects)
- Option B: Keep it if your project is also a template
- Option C: Move relevant content to your own project documentation

See OPTIONAL_CONFIGURATIONS.md for detailed guidance on CONTRIBUTING.md customization.
-->

This repository is a template designed for projects that use GitHub Copilot for AI-assisted development.

### Understanding the Instruction Files

The `.github/instructions/` directory contains coding standards that guide GitHub Copilot's code generation:

- **`docs.instructions.md`** - Documentation and Markdown writing standards
- **`powershell.instructions.md`** - PowerShell coding conventions (OTBS style, v1.0 compatibility patterns)
- **`python.instructions.md`** - Python coding standards (PEP 8, type hints, testing patterns)

These instruction files are automatically applied by GitHub Copilot based on the file patterns specified in each file's front matter.

### Customizing for Your Project

You can customize these instruction files for your project's specific conventions:

1. Edit the instruction files to match your team's coding standards
2. Remove instruction files for languages you don't use
3. Add new instruction files for additional languages as needed

### First-Time Setup Validation

After creating a new repository from this template, see the [Validating Your New Repository](README.md#validating-your-new-repository) section in the README for guidance on verifying your setup.
