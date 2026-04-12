# Contributing to GloryRole

Thank you for your interest in contributing! This document provides guidelines for contributing to this repository.

## Development Setup

### 1. Clone the Repository

```bash
git clone https://github.com/franklesniak/GloryRole.git
cd GloryRole
```

### 2. Install Node.js Dependencies (for Markdown linting)

```bash
npm install
```

This installs Node.js dependencies for markdown linting scripts. Git hooks are managed by pre-commit (see step 4 below).

### Repository Layout

| Directory | Purpose |
| --- | --- |
| `src/` | PowerShell function files and module manifest (`GloryRole.psd1`) |
| `tests/PowerShell/` | Pester 5.x test files |
| `build/` | Build script (`Build-Module.ps1`) |
| `samples/` | Sample data for demo and testing |
| `docs/` | Specification and design documentation |

### Git Hooks

This repository uses pre-commit for git hooks. Configured hooks include:

- **Formatting**: Trailing whitespace removal, end-of-file fixer
- **Linting**: markdownlint (Markdown), YAML validation
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

### 3. Install pre-commit (Globally)

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
- It manages its own isolated environments for hooks
- Installing it globally or via `pipx` keeps it separate from project dependencies
- CI workflows install `pre-commit` separately in their own steps

### 4. Install Pre-commit Hooks

After installing `pre-commit` globally, set up the hooks in your local repository:

```bash
pre-commit install
```

This configures Git to automatically run pre-commit hooks before each commit.

### 5. Run Pre-commit Manually

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

**CRITICAL: Always run pre-commit checks before committing code.**

Pre-commit hooks are NOT optional. They enforce:

- Code formatting (markdownlint for Markdown, whitespace cleanup)
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

- **PowerShell:** `.github/instructions/powershell.instructions.md`
- **Markdown/Documentation:** `.github/instructions/docs.instructions.md`

These standards are enforced by GitHub Copilot and should be followed for all contributions.

### CI Workflows

This repository includes several GitHub Actions workflows that run automatically:

| Workflow | File | Purpose |
| --- | --- | --- |
| Markdown Lint | `.github/workflows/markdownlint.yml` | Validates markdown formatting |
| PowerShell CI | `.github/workflows/powershell-ci.yml` | Runs PSScriptAnalyzer and Pester tests on PowerShell files |
| Build Module | `.github/workflows/build-module.yml` | Builds the GloryRole module artifact |
| Auto-fix Pre-commit | `.github/workflows/auto-fix-precommit.yml` | Automatically commits pre-commit fixes on PRs (optional) |

The **Auto-fix Pre-commit** workflow is particularly useful for AI-assisted development (e.g., GitHub Copilot Coding Agent) as it automatically commits formatting fixes to PR branches.

## Making Changes

### 1. Create a Branch

```bash
git checkout -b your-feature-branch
```

### 2. Make Your Changes

Follow the coding standards for the language(s) you're working with.

### 3. Build the Module

```powershell
./build/Build-Module.ps1
```

This produces the bundled module in `out/GloryRole/`.

### 4. Run Pre-commit Hooks

```bash
pre-commit run --all-files
```

Fix any issues that are reported.

### 5. Run Tests

Before submitting a pull request, ensure all tests pass locally.

#### PowerShell Tests

```powershell
# Install Pester if not already installed
Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser

# Run all Pester tests
Invoke-Pester -Path tests/ -Output Detailed
```

#### Test Requirements

- **PowerShell:** New functions should include Pester tests in `tests/PowerShell/`
- All tests must pass on the CI matrix (Ubuntu, Windows, macOS)

### 6. Commit Your Changes

```bash
git add .
git commit -m "Your descriptive commit message"
```

Pre-commit hooks will run automatically. If they make changes, review them and commit again.

### 7. Push Your Branch

```bash
git push origin your-feature-branch
```

### 8. Open a Pull Request

Open a PR on GitHub and fill out the PR template checklist.

## Pull Request Guidelines

When submitting a pull request:

- [ ] Confirm `pre-commit run --all-files` passes locally
- [ ] Include tests for new functionality
- [ ] Update documentation as needed
- [ ] Ensure all CI checks pass

## Questions or Issues?

If you have questions or encounter issues:

1. Check existing [Issues](https://github.com/franklesniak/GloryRole/issues)
2. Review the documentation in `.github/instructions/`
3. Open a new issue with a clear description of the problem

## License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project (MIT License).
