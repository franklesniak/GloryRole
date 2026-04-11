# Project Name

> **Note:** This repository was created from [`franklesniak/copilot-repo-template`](https://github.com/franklesniak/copilot-repo-template).

## Description

[Add your project description here]

---

## Table of Contents

- [Readme for the Copilot Repository Template](#readme-for-the-copilot-repository-template)
  - [What This Template Provides](#what-this-template-provides)
  - [Getting Started](#getting-started)
  - [Repository Structure](#repository-structure)
  - [Language Support](#language-support)
  - [Linting Tools](#linting-tools)
  - [Testing](#testing)
  - [Code Quality](#code-quality)
  - [License](#license)

---

## Readme for the Copilot Repository Template

This is a template repository providing best-practice GitHub Copilot instructions and linting configurations for new projects.

### What This Template Provides

This template includes:

- **GitHub Copilot Instructions:** Comprehensive coding standards that guide AI-assisted development
- **Multi-Agent Support:** Instruction files for Claude Code, OpenAI Codex CLI, and Gemini Code Assist (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`)
- **Language-Specific Guidelines:** Modular instruction files for Markdown, PowerShell, and Python
- **Linting Configurations:** Pre-configured settings for markdownlint and PSScriptAnalyzer
- **Pre-commit Hooks:** Automated code quality checks before commits

### Getting Started

Choose the guide that matches your situation:

- **[Creating a New Repository](GETTING_STARTED_NEW_REPO.md)**: Step-by-step guide for creating a new repository from this template
- **[Adding to an Existing Repository](GETTING_STARTED_EXISTING_REPO.md)**: Guide for adopting template features into an existing repository
- **[Optional Configurations](OPTIONAL_CONFIGURATIONS.md)**: Advanced customization options after initial setup

For template maintainers, see [TEMPLATE_MAINTENANCE.md](TEMPLATE_MAINTENANCE.md).

### Repository Structure

```text
.github/
├── CODEOWNERS                       # Code ownership for automatic PR review requests
├── copilot-instructions.md          # Repo-wide constitution for all changes
├── dependabot.yml                   # Automated dependency updates configuration
├── instructions/                    # Language-specific coding standards
│   ├── docs.instructions.md         # Markdown/documentation standards
│   ├── powershell.instructions.md   # PowerShell coding standards
│   └── python.instructions.md       # Python coding standards
├── linting/                         # Linting tool configurations
│   └── PSScriptAnalyzerSettings.psd1  # PowerShell linting settings
├── scripts/                         # Helper scripts for CI/tooling
└── workflows/                       # GitHub Actions workflows
    ├── check-placeholders.yml       # Verifies OWNER/REPO placeholders are replaced
    └── powershell-ci.yml            # PowerShell linting and testing CI (optional)
    └── python-ci.yml                 # Python linting and testing CI (optional)

src/
└── copilot_repo_template/           # Example Python package (rename for your project)
    ├── __init__.py
    └── example.py

tests/                               # Test directory
├── __init__.py
├── test_example.py                  # Python pytest tests
└── PowerShell/                      # PowerShell Pester tests
    └── Placeholder.Tests.ps1

templates/                           # Reference templates for project setup
├── python/                          # Python project templates
└── powershell/                      # PowerShell test templates
    └── Example.Tests.ps1            # Comprehensive Pester test example

pyproject.toml                       # Python project configuration
.markdownlint.jsonc                  # Markdown linting configuration
.pre-commit-config.yaml              # Pre-commit hooks (Python focused)
AGENTS.md                            # Agent instructions for OpenAI Codex CLI
CLAUDE.md                            # Agent instructions for Claude Code
GEMINI.md                            # Agent instructions for Gemini Code Assist
```

#### Key Files Explained

| File | Purpose |
| --- | --- |
| `.github/CODEOWNERS` | Defines code ownership for automatic PR review requests - replace `@OWNER` placeholder |
| `.github/copilot-instructions.md` | The "constitution" for all code changes - defines safety rules, pre-commit discipline, and references language-specific instructions |
| `.github/dependabot.yml` | Dependabot configuration for automated dependency updates - enabled by default |
| `.github/instructions/*.md` | Language-specific coding standards applied based on file patterns |
| `.github/linting/PSScriptAnalyzerSettings.psd1` | PSScriptAnalyzer settings enforcing OTBS formatting for PowerShell |
| `.github/workflows/check-placeholders.yml` | CI workflow to verify OWNER/REPO and @OWNER placeholders are replaced after cloning |
| `.github/workflows/powershell-ci.yml` | PowerShell linting and Pester testing CI workflow (optional - remove if not using PowerShell) |
| `.github/workflows/python-ci.yml` | Python linting and testing CI workflow (optional - remove if not using Python) |
| `.markdownlint.jsonc` | Markdown linting rules prioritizing auto-fixable checks |
| `.pre-commit-config.yaml` | Pre-commit hooks for all projects (Python formatting, linting, Markdown) |
| `AGENTS.md` | Agent instructions for OpenAI Codex CLI and GitHub Copilot coding agent |
| `CLAUDE.md` | Agent instructions for Claude Code and GitHub Copilot coding agent |
| `GEMINI.md` | Agent instructions for Gemini Code Assist and GitHub Copilot coding agent |
| `pyproject.toml` | Python project configuration with dev dependencies |
| `src/copilot_repo_template/` | Example Python package - rename for your project |
| `tests/` | Test directory with pytest tests (Python) and Pester tests (PowerShell) |
| `templates/powershell/Example.Tests.ps1` | Comprehensive Pester test template with examples |

### Language Support

| Language | Instruction File | File Pattern | CI Workflow | Description |
| --- | --- | --- | --- | --- |
| Markdown/Docs | `.github/instructions/docs.instructions.md` | `**/*.md` | `.github/workflows/markdownlint.yml` | Documentation writing standards |
| PowerShell | `.github/instructions/powershell.instructions.md` | `**/*.ps1` | `.github/workflows/powershell-ci.yml` | PowerShell coding standards (OTBS, v1.0-v7.x) |
| Python | `.github/instructions/python.instructions.md` | `**/*.py` | `.github/workflows/python-ci.yml` | Python coding standards (PEP 8, typing) |
| Terraform | `.github/instructions/terraform.instructions.md` | `**/*.tf`, `**/*.tfvars`, `**/*.tftest.hcl`, etc. | `.github/workflows/terraform-ci.yml` | Terraform coding standards (HCL, modules) |

### Linting Tools

This template organizes linting configurations in `.github/linting/` (for PSScriptAnalyzer) and the repository root (for markdownlint). Projects MAY reorganize these configurations to a different location (e.g., a project-specific `config/` directory) if preferred. If configurations are moved, update the paths referenced in CI workflows and `.github/copilot-instructions.md` accordingly.

#### Markdown Linting

Configuration: `.markdownlint.jsonc`

```bash
# Check markdown files
npm run lint:md

# Auto-fix issues
npx markdownlint-cli2 "**/*.md" "#node_modules" --fix
```

#### PowerShell Linting (PSScriptAnalyzer)

Configuration: `.github/linting/PSScriptAnalyzerSettings.psd1`

```powershell
# Check PowerShell files
Invoke-ScriptAnalyzer -Path .\script.ps1 -Settings .\.github\linting\PSScriptAnalyzerSettings.psd1

# Auto-fix formatting issues
Invoke-ScriptAnalyzer -Path .\script.ps1 -Settings .\.github\linting\PSScriptAnalyzerSettings.psd1 -Fix
```

#### Python Linting

Configuration: `.pre-commit-config.yaml`

```bash
# Run all pre-commit hooks
pre-commit run --all-files

# Run specific hooks
pre-commit run black --all-files
pre-commit run ruff-check --all-files
```

#### Terraform Linting

This repository includes Terraform linting via:

- **terraform fmt:** Format checking and auto-formatting
- **terraform validate:** Configuration validation
- **TFLint:** Best practice linting with cloud provider plugins

Configuration: `.tflint.hcl`

```bash
# Format check
terraform fmt -check -recursive

# Format fix
terraform fmt -recursive

# Validate (requires init)
terraform init -backend=false && terraform validate

# Lint
tflint --init && tflint --recursive
```

### Testing

#### Python Tests

Python tests use pytest with coverage reporting.

```bash
# Run all Python tests
pytest tests/ -v --cov --cov-report=term-missing

# Run a specific test file
pytest tests/test_example.py -v
```

#### PowerShell Tests

PowerShell tests use Pester 5.x.

```powershell
# Install Pester if needed
Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser

# Run all Pester tests
Invoke-Pester -Path tests/ -Output Detailed

# Run a specific test file
Invoke-Pester -Path tests/PowerShell/Placeholder.Tests.ps1
```

CI runs PowerShell tests on Windows, macOS, and Linux to ensure cross-platform compatibility.

See `templates/powershell/Example.Tests.ps1` for a comprehensive Pester test template.

#### Terraform Tests

Terraform tests use the native Terraform test framework (Terraform 1.6+).

```bash
# Run all Terraform tests
terraform test -verbose

# Run specific test file
terraform test -filter=tests/unit.tftest.hcl
```

Tests are located in `modules/*/tests/` directories.

See `templates/terraform/Example.tftest.hcl` for a comprehensive Terraform test template.

### Code Quality

This repository enforces code quality through:

- **Markdown Linting:** Runs on pre-commit and in CI
- **GitHub Copilot Instructions:** Guides AI-assisted development
- **Pre-commit Hooks:** Catches issues before they reach CI
- **PSScriptAnalyzer:** PowerShell static analysis with OTBS formatting
- **TFLint:** Terraform linting with configurable rules and cloud provider plugins

### License

MIT License - See [LICENSE](LICENSE) for details.
