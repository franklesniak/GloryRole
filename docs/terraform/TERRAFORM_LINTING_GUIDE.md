# Terraform Linting Implementation Guide

**Version:** 1.0.20260124.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-01-24
- **Scope:** This document provides comprehensive guidance for implementing Terraform linting in CI for the `franklesniak/copilot-repo-template` repository. It covers tool selection, workflow design, configuration, pre-commit integration, and best practices. This is a **guidance-only** document—it does not modify workflows or configurations directly.
- **Related:** [Repository Copilot Instructions](../../.github/copilot-instructions.md), [Terraform Instructions](../../.github/instructions/terraform.instructions.md)

---

## Table of Contents

- [Introduction](#introduction)
- [Linting Tool Analysis](#linting-tool-analysis)
  - [terraform fmt](#terraform-fmt)
  - [terraform validate](#terraform-validate)
  - [TFLint](#tflint)
  - [Checkov](#checkov)
  - [tfsec](#tfsec)
  - [Terrascan](#terrascan)
  - [Tool Recommendation Summary](#tool-recommendation-summary)
- [GitHub Actions Workflow Recommendations](#github-actions-workflow-recommendations)
  - [Workflow Structure](#workflow-structure)
  - [Job Organization](#job-organization)
  - [Job Configuration Details](#job-configuration-details)
  - [Matrix Strategy Considerations](#matrix-strategy-considerations)
  - [Caching Strategies](#caching-strategies)
  - [Security Scanning Guidance](#security-scanning-guidance)
- [Configuration File Recommendations](#configuration-file-recommendations)
  - [TFLint Configuration Structure](#tflint-configuration-structure)
  - [Configuration File Placement](#configuration-file-placement)
  - [Recommended Rule Sets and Plugins](#recommended-rule-sets-and-plugins)
  - [Rule Customization](#rule-customization)
- [Pre-commit Integration](#pre-commit-integration)
  - [Recommended Hooks](#recommended-hooks)
  - [Updating pre-commit-config.yaml](#updating-pre-commit-configyaml)
  - [Local Workflow](#local-workflow)
  - [Troubleshooting Pre-commit Hooks](#troubleshooting-pre-commit-hooks)
- [CI Workflow Design Decisions](#ci-workflow-design-decisions)
  - [Header Comment Documentation](#header-comment-documentation)
  - [Job Dependencies](#job-dependencies)
  - [Continue-on-error Usage](#continue-on-error-usage)
  - [Multiple Terraform Roots](#multiple-terraform-roots)
  - [Path Filtering](#path-filtering)
  - [Failure Handling](#failure-handling)
- [Integration with Existing Infrastructure](#integration-with-existing-infrastructure)
  - [Auto-fix Workflow Integration](#auto-fix-workflow-integration)
  - [Updates to copilot-instructions.md](#updates-to-copilot-instructionsmd)
  - [README Update Recommendations](#readme-update-recommendations)
- [Versioning Policy Guidance](#versioning-policy-guidance)
- [Summary of Recommended Steps](#summary-of-recommended-steps)

---

## Introduction

This guide provides comprehensive recommendations for implementing Terraform linting in CI for this repository. The goal is to establish a consistent, secure, and maintainable Terraform development workflow that:

- **Catches formatting issues** before code review
- **Validates configuration syntax** before apply operations
- **Enforces coding standards** via configurable linting rules
- **Identifies security vulnerabilities** through static analysis
- **Integrates seamlessly** with the existing pre-commit and CI infrastructure

All recommendations in this guide follow the patterns established in this repository's existing Python and PowerShell CI workflows. This guide uses RFC 2119 keywords (**MUST**, **SHOULD**, **MAY**, etc.) to indicate requirement levels.

---

## Linting Tool Analysis

This section provides a comprehensive comparison of Terraform linting tools to inform tool selection.

### terraform fmt

**Official Documentation:** [terraform fmt Command](https://developer.hashicorp.com/terraform/cli/commands/fmt)

#### What It Does

`terraform fmt` reformats Terraform configuration files to a canonical format and style. It applies HashiCorp's style conventions consistently across all `.tf` files.

#### How to Run

```bash
# Check mode (returns exit code 1 if changes needed)
terraform fmt -check -recursive -diff

# Write mode (modifies files in-place)
terraform fmt -recursive
```

#### Modes

| Mode | Flag | Behavior | CI Use |
| --- | --- | --- | --- |
| Check | `-check` | Returns exit code 1 if changes needed, does not modify files | **Required** in CI |
| Write | (default) | Modifies files in-place | Pre-commit only |
| Diff | `-diff` | Shows differences when used with `-check` | Recommended for debugging |
| Recursive | `-recursive` | Processes subdirectories | Always use |

#### Pros

- **Built-in:** No additional installation required (bundled with Terraform)
- **Deterministic:** Produces identical output regardless of initial formatting
- **Fast:** Minimal overhead for format checking
- **Auto-fixable:** Can automatically correct issues in pre-commit

#### Cons

- **Limited scope:** Only checks formatting, not validity or best practices
- **No customization:** Style rules are not configurable

#### When to Use

`terraform fmt` **MUST** be the first check in any Terraform CI pipeline. It ensures consistent formatting before any other validation occurs.

---

### terraform validate

**Official Documentation:** [terraform validate Command](https://developer.hashicorp.com/terraform/cli/commands/validate)

#### What It Validates

`terraform validate` checks configuration files for syntax errors and internal consistency. It validates:

- HCL syntax correctness
- Attribute types and values
- Required arguments are present
- Module source paths exist
- Variable and output declarations are valid

#### Initialization Requirements

`terraform validate` **requires** `terraform init` to be run first to:

- Download provider plugins
- Initialize backend configuration
- Download module sources

For CI validation, use `-backend=false` to skip backend initialization:

```bash
terraform init -backend=false
terraform validate
```

#### How to Run

```bash
# Basic validation (requires init first)
terraform validate

# With JSON output for parsing
terraform validate -json
```

#### Pros

- **Built-in:** No additional installation required
- **Comprehensive:** Catches syntax errors and type mismatches
- **Provider-aware:** Validates against actual provider schemas

#### Cons

- **Requires init:** Must download providers before validation
- **No best practices:** Does not enforce coding standards
- **No security scanning:** Does not identify security issues
- **Slower:** Network calls to download providers

#### When to Use

`terraform validate` **SHOULD** run after `terraform fmt` to catch configuration errors before linting. It validates that the configuration is syntactically correct and internally consistent.

---

### TFLint

**Official Documentation:** [TFLint](https://github.com/terraform-linters/tflint)

#### Purpose and Capabilities

TFLint is a pluggable Terraform linter that enforces best practices and coding standards. Key capabilities:

- **Syntax linting:** Variable naming, deprecated syntax, unused declarations
- **Best practice enforcement:** Module versioning, provider versioning, required blocks
- **Provider-specific rules:** AWS, Azure, GCP plugins for cloud-specific linting
- **Extensibility:** Custom rules via plugins

#### Plugin Ecosystem

| Plugin | Source | Purpose |
| --- | --- | --- |
| terraform | Built-in | Core Terraform rules |
| aws | `terraform-linters/tflint-ruleset-aws` | AWS resource validation |
| azurerm | `terraform-linters/tflint-ruleset-azurerm` | Azure resource validation |
| google | `terraform-linters/tflint-ruleset-google` | GCP resource validation |

#### Configuration Options

TFLint is configured via `.tflint.hcl`:

```hcl
# .tflint.hcl - Basic configuration
config {
  format = "compact"           # Output format: default, json, checkstyle, compact
  call_module_type = "local"   # Which modules to inspect: local, all, none
  force = false                # Continue on errors
  disabled_by_default = false  # Start with all rules enabled
}

# Enable Terraform plugin with recommended preset
plugin "terraform" {
  enabled = true
  preset  = "recommended"      # all, recommended, none
}
```

#### How to Run

```bash
# Initialize plugins (downloads ruleset plugins)
tflint --init

# Run linting (current directory)
tflint

# Recursive mode (all subdirectories)
tflint --recursive

# With specific config file
tflint --config /path/to/.tflint.hcl
```

#### Pros

- **Configurable:** Fine-grained control over which rules to enable
- **Extensible:** Plugin ecosystem for cloud providers
- **Fast:** Efficient static analysis
- **Active development:** Well-maintained with regular updates

#### Cons

- **Additional tool:** Requires separate installation
- **Plugin management:** Cloud provider plugins require initialization
- **No security focus:** Not designed for security scanning

#### Recommended Use Cases

TFLint **SHOULD** be the primary linting tool for enforcing coding standards. Use the `recommended` preset and enable cloud provider plugins as needed.

---

### Checkov

**Official Documentation:** [Checkov](https://www.checkov.io/)

#### Purpose and Capabilities

Checkov is a static code analysis tool for infrastructure as code that scans for security and compliance misconfigurations. Key capabilities:

- **Security scanning:** Identifies insecure configurations (open security groups, unencrypted storage, etc.)
- **Compliance frameworks:** Supports CIS, SOC2, HIPAA, PCI-DSS, and more
- **Multi-IaC support:** Terraform, CloudFormation, Kubernetes, ARM templates, etc.
- **Custom policies:** Write custom policies in Python or YAML

#### Policy Coverage

Checkov includes 1000+ built-in policies covering:

- Network security (security groups, NACLs, firewall rules)
- Encryption at rest and in transit
- IAM and access control
- Logging and monitoring
- Data protection
- Container security

#### Custom Policy Support

Custom policies can be defined in:

- **Python:** Full programmatic control
- **YAML:** Declarative policy definitions

```yaml
# Example custom policy (custom_policy.yaml)
metadata:
  name: "Ensure S3 bucket has versioning enabled"
  id: "CUSTOM_S3_001"
  category: "general"
definition:
  and:
    - cond_type: "attribute"
      attribute: "versioning.enabled"
      operator: "equals"
      value: "true"
```

#### How to Run

```bash
# Basic scan
checkov -d /path/to/terraform

# Specific framework
checkov -d /path/to/terraform --framework terraform

# With output file
checkov -d . -o sarif > checkov-results.sarif

# Soft fail (exit 0 even with findings)
checkov -d . --soft-fail
```

#### Pros

- **Comprehensive:** Extensive policy coverage out of the box
- **Multi-framework:** Supports many IaC formats
- **Compliance-focused:** Built-in compliance framework mappings
- **Active community:** Regular policy updates

#### Cons

- **Python dependency:** Requires Python runtime
- **Slower:** More comprehensive scans take longer
- **Noisy:** Can produce many findings on existing codebases
- **Overlap with tfsec:** Some redundancy in security scanning

#### When to Use

Checkov is **RECOMMENDED** when compliance framework mappings are required or when scanning multiple IaC formats. For pure Terraform security scanning, consider tfsec as a lighter alternative.

---

### tfsec

**Official Documentation:** [tfsec](https://github.com/aquasecurity/tfsec) (now part of Trivy)

> **Note:** tfsec has been integrated into Trivy. While tfsec remains available as a standalone tool, Aqua Security recommends using Trivy for new implementations.

#### Purpose and Capabilities

tfsec is a security scanner for Terraform that identifies potential security issues. Key capabilities:

- **Security-focused:** Purpose-built for Terraform security scanning
- **Fast:** Written in Go, optimized for speed
- **Terraform-native:** Deep understanding of Terraform semantics
- **GitHub integration:** Native SARIF output for code scanning

#### Differences vs Checkov

| Aspect | tfsec | Checkov |
| --- | --- | --- |
| Focus | Security only | Security + compliance |
| Speed | Faster | Slower |
| Language | Go | Python |
| IaC support | Terraform only | Multi-framework |
| Policy format | Go | Python/YAML |
| Compliance | Limited | Extensive |

#### How to Run

```bash
# Basic scan
tfsec .

# With SARIF output (for GitHub code scanning)
tfsec . --format sarif > tfsec-results.sarif

# Soft fail
tfsec . --soft-fail

# Minimum severity
tfsec . --minimum-severity HIGH
```

#### Pros

- **Fast:** Efficient Go implementation
- **Focused:** Security-only means less noise
- **Easy setup:** Single binary, no dependencies
- **GitHub native:** Excellent CI integration

#### Cons

- **Deprecated path:** Migrating to Trivy
- **Terraform only:** No multi-framework support
- **Less compliance:** Limited compliance framework support

#### When to Use

tfsec is **RECOMMENDED** as the primary security scanner for Terraform-only repositories that don't require extensive compliance framework mappings.

---

### Terrascan

**Official Documentation:** [Terrascan](https://github.com/tenable/terrascan)

#### Purpose and Capabilities

Terrascan is a static code analyzer for Infrastructure as Code that detects compliance and security violations. Key capabilities:

- **Policy as Code:** Uses Rego (Open Policy Agent) for policy definitions
- **Multi-IaC support:** Terraform, Kubernetes, AWS CloudFormation, Azure ARM, GCP Deployment Manager
- **CI/CD integration:** Supports various CI platforms
- **Extensibility:** Custom policies via Rego

#### Policy as Code Support

Terrascan uses Open Policy Agent (OPA) Rego for policies:

```rego
# Example Rego policy
package accurics

# Ensure S3 bucket is encrypted
encryptedS3Bucket[resource.id] {
    resource := input.aws_s3_bucket[_]
    not resource.config.server_side_encryption_configuration
}
```

#### How to Run

```bash
# Basic scan
terrascan scan

# Specify IaC type
terrascan scan -i terraform

# With output format
terrascan scan -o sarif

# Custom policy path
terrascan scan -p /path/to/policies
```

#### Pros

- **OPA/Rego policies:** Industry-standard policy language
- **Multi-IaC:** Broad infrastructure support
- **Active development:** Maintained by Tenable

#### Cons

- **Rego learning curve:** Custom policies require Rego knowledge
- **Less Terraform-specific:** Generalist approach
- **Smaller community:** Fewer resources than Checkov/tfsec

#### When to Use

Terrascan is **RECOMMENDED** when OPA/Rego policy standardization is required across multiple IaC types or when integrating with existing OPA infrastructure.

---

### Tool Recommendation Summary

Based on the analysis above, here are the recommended tools for this repository:

#### Recommended Toolchain

| Tool | Purpose | Priority | Rationale |
| --- | --- | --- | --- |
| `terraform fmt` | Format checking | **Required** | Built-in, fast, deterministic |
| `terraform validate` | Syntax validation | **Required** | Built-in, catches configuration errors |
| TFLint | Linting/best practices | **Required** | Configurable, extensible, well-maintained |
| tfsec (or Trivy) | Security scanning | **Recommended** | Fast, focused, Terraform-native |

#### Why This Combination

1. **No redundancy:** Each tool has a distinct purpose
2. **Fast feedback:** Format and validation checks run quickly
3. **Configurable:** TFLint provides fine-grained control over linting rules
4. **Security coverage:** tfsec provides security scanning without compliance overhead
5. **Existing integration:** TFLint is already configured in this repository's `.tflint.hcl` and pre-commit

#### When to Add Additional Tools

- **Add Checkov:** When compliance framework mappings (CIS, SOC2, HIPAA) are required
- **Add Terrascan:** When OPA/Rego policy standardization is required
- **Use Trivy instead of tfsec:** For new implementations (tfsec is deprecated)

#### Avoiding Redundant Scans

Running multiple security scanners (Checkov + tfsec + Terrascan) is **NOT RECOMMENDED** because:

- Increased CI time with diminishing returns
- Conflicting/duplicate findings create noise
- Policy management becomes complex

**SHOULD** choose one primary security scanner and use others only for advisory purposes (with `continue-on-error: true`).

---

## GitHub Actions Workflow Recommendations

This section provides detailed guidance on implementing Terraform linting in GitHub Actions, following the patterns established in this repository.

### Workflow Structure

#### Consolidated Single Workflow Approach

Following the pattern in `python-ci.yml`, Terraform CI **SHOULD** use a single consolidated workflow with job dependencies:

```yaml
# .github/workflows/terraform-ci.yml
# Single workflow with job dependencies

name: Terraform CI

on:
  push:
    branches: ["**"]
  pull_request:
    branches: ["**"]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  format:
    # Format checking job
    # ...

  validate:
    needs: format
    # Validation job
    # ...

  lint:
    needs: validate
    # TFLint job
    # ...

  security:
    needs: validate
    # Security scanning (optional)
    # ...
```

#### Benefits of This Approach

- **All jobs appear in PR checks:** Not hidden in Actions tab
- **Easy branch ruleset setup:** Configure required jobs directly
- **Efficient CI minutes:** Failed jobs skip downstream work
- **Simpler maintenance:** Single file to manage

#### Header Comment Documentation

Following the established pattern, the workflow file **MUST** include a comprehensive header comment:

```yaml
# Terraform CI Workflow
#
# Purpose: Run format checking, validation, linting, and optional security
# scanning for Terraform code in a single consolidated workflow.
#
# Design Decisions:
#
# 1. Single Workflow with Job Dependencies:
#    This workflow combines format, validate, lint, and security into a single
#    workflow file using the `needs:` keyword for job dependencies.
#
# 2. Job Dependencies:
#    - validate needs format (don't validate poorly-formatted code)
#    - lint needs validate (don't lint invalid code)
#    - security needs validate (runs in parallel with lint)
#
# 3. Template Repository Consideration:
#    This workflow does NOT use path-based filtering because this is a template
#    repository. Template repositories should run all workflows on all changes.
#
# 4. Terraform Version Policy:
#    Pin to a specific Terraform version for reproducibility. Update when
#    upstream support changes.
#
# Note: This workflow is optional. Remove if your project doesn't use Terraform.
```

---

### Job Organization

#### Recommended Job Structure

```yaml
jobs:
  format:
    name: Format Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.0"
      - name: Terraform Format Check
        run: terraform fmt -check -recursive -diff

  validate:
    name: Validate
    needs: format
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.0"
      - name: Find Terraform Directories
        id: find-dirs
        run: |
          TF_DIRS=$(find . -name '*.tf' -exec dirname {} \; | sort -u | tr '\n' ' ')
          echo "dirs=${TF_DIRS}" >> $GITHUB_OUTPUT
      - name: Terraform Init and Validate
        run: |
          for dir in ${{ steps.find-dirs.outputs.dirs }}; do
            echo "=== Validating $dir ==="
            cd "$dir"
            terraform init -backend=false
            terraform validate
            cd - > /dev/null
          done

  lint:
    name: Lint (TFLint)
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: v0.51.1  # Pin version for reproducibility
      - name: Init TFLint
        run: tflint --init
      - name: Run TFLint
        run: tflint --recursive --config "$(pwd)/.tflint.hcl"

  security:
    name: Security Scan (Optional)
    needs: validate
    runs-on: ubuntu-latest
    continue-on-error: true  # Advisory, not blocking
    steps:
      - uses: actions/checkout@v4
      - uses: aquasecurity/tfsec-action@v1.0.3
        with:
          soft_fail: true
```

#### Job Dependencies Diagram

```text
format
   │
   ▼
validate
   │
   ├───────────┐
   ▼           ▼
 lint       security
```

#### Rationale for Dependencies

- **format → validate:** Don't validate poorly-formatted code; formatting issues should be fixed first
- **validate → lint:** Don't lint invalid configuration; syntax errors should be fixed first
- **validate → security:** Security scanning can run in parallel with linting (both depend on valid code)

---

### Job Configuration Details

#### Runner Selection

| Job | Recommended Runner | Rationale |
| --- | --- | --- |
| format | `ubuntu-latest` | Terraform is cross-platform; Linux is fastest |
| validate | `ubuntu-latest` | Provider downloads faster on Linux |
| lint | `ubuntu-latest` | TFLint is available on all platforms |
| security | `ubuntu-latest` | Security tools optimized for Linux |

#### Terraform Version Setup

Use `hashicorp/setup-terraform` for consistent Terraform installation:

```yaml
- uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: "1.6.0"  # Pin specific version
    terraform_wrapper: true      # Enables output capturing
```

**Official Documentation:** [hashicorp/setup-terraform](https://github.com/hashicorp/setup-terraform)

#### Permissions Requirements

Follow least-privilege principles:

```yaml
permissions:
  contents: read  # Minimum required for checkout
```

For security scanning with SARIF upload:

```yaml
permissions:
  contents: read
  security-events: write  # Required for code scanning upload
```

---

### Matrix Strategy Considerations

#### When Matrix Testing Is Useful

Matrix testing across Terraform versions is useful when:

- Publishing reusable modules that must support multiple Terraform versions
- Migrating from an older Terraform version
- Testing provider compatibility across versions

#### When Matrix Testing Is Overkill

Matrix testing is **NOT RECOMMENDED** for:

- Internal infrastructure code (pin to one version)
- Template repositories (test with recommended version only)
- Simple configurations without version-sensitive features

#### Example Matrix Configuration

```yaml
# Only use when testing module compatibility
strategy:
  matrix:
    terraform-version: ['1.5.0', '1.6.0', '1.7.0']

steps:
  - uses: hashicorp/setup-terraform@v3
    with:
      terraform_version: ${{ matrix.terraform-version }}
```

---

### Caching Strategies

#### Provider Caching

Cache the Terraform plugin directory to avoid repeated provider downloads:

```yaml
- name: Cache Terraform Providers
  uses: actions/cache@v4
  with:
    path: ~/.terraform.d/plugin-cache
    key: terraform-providers-${{ hashFiles('**/.terraform.lock.hcl') }}
    restore-keys: |
      terraform-providers-

- name: Configure Provider Cache
  run: |
    mkdir -p ~/.terraform.d/plugin-cache
    echo "plugin_cache_dir = \"$HOME/.terraform.d/plugin-cache\"" > ~/.terraformrc
```

#### TFLint Plugin Caching

Cache TFLint plugins to avoid repeated downloads:

```yaml
- name: Cache TFLint Plugins
  uses: actions/cache@v4
  with:
    path: ~/.tflint.d/plugins
    key: tflint-plugins-${{ hashFiles('.tflint.hcl') }}
    restore-keys: |
      tflint-plugins-
```

#### Cache Key Strategy

| Cache Type | Key Strategy | Invalidation Trigger |
| --- | --- | --- |
| Terraform providers | Hash of `.terraform.lock.hcl` | Provider version changes |
| TFLint plugins | Hash of `.tflint.hcl` | Plugin configuration changes |
| Pre-commit hooks | Hash of `.pre-commit-config.yaml` | Hook version changes |

---

### Security Scanning Guidance

#### Recommended Primary Scanner

**SHOULD** use one primary security scanner and treat others as optional/advisory:

| Scanner | Recommendation | Configuration |
| --- | --- | --- |
| tfsec/Trivy | Primary | `continue-on-error: false` |
| Checkov | Optional | `continue-on-error: true` |
| Terrascan | Optional | `continue-on-error: true` |

#### Example Configuration

```yaml
security:
  name: Security Scan
  needs: validate
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4

    # Primary scanner (required)
    - name: Run tfsec
      uses: aquasecurity/tfsec-action@v1.0.3
      with:
        soft_fail: false  # Fail on findings

    # Advisory scanner (optional)
    - name: Run Checkov (Advisory)
      uses: bridgecrewio/checkov-action@v12
      continue-on-error: true  # Don't fail workflow
      with:
        directory: .
        framework: terraform
        soft_fail: true
```

---

## Configuration File Recommendations

### TFLint Configuration Structure

The repository already includes a `.tflint.hcl` configuration file. This section documents the recommended structure and options.

#### Basic Structure

```hcl
# .tflint.hcl

# Global configuration
config {
  format = "compact"           # Output format
  call_module_type = "local"   # Module inspection scope
  force = false                # Continue on errors
  disabled_by_default = false  # Start with rules enabled
}

# Core Terraform plugin
plugin "terraform" {
  enabled = true
  preset  = "recommended"      # Preset: all, recommended, none
}

# Provider-specific plugins (enable as needed)
# plugin "aws" { ... }
# plugin "azurerm" { ... }
# plugin "google" { ... }

# Rule-specific configuration
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}
```

#### Configuration Options Reference

| Option | Values | Description |
| --- | --- | --- |
| `format` | `default`, `json`, `checkstyle`, `compact`, `sarif` | Output format |
| `call_module_type` | `local`, `all`, `none` | Which modules to inspect |
| `force` | `true`, `false` | Continue on errors |
| `disabled_by_default` | `true`, `false` | Start with rules disabled |

---

### Configuration File Placement

#### Options Comparison

| Location | Pros | Cons |
| --- | --- | --- |
| `.tflint.hcl` (repo root) | Standard location, easy to find | Clutters repo root |
| `.github/linting/.tflint.hcl` | Centralized with other linting configs | Non-standard, requires config path |

#### Recommendation

**SHOULD** place `.tflint.hcl` in the repository root for the following reasons:

1. **Standard location:** TFLint looks for `.tflint.hcl` in the working directory by default
2. **Tool compatibility:** IDE plugins and pre-commit hooks expect this location
3. **Consistency:** Matches Terraform's other config files (`.terraform.lock.hcl`)

The existing repository configuration follows this pattern correctly.

---

### Recommended Rule Sets and Plugins

#### Core Rules (Recommended)

The following rules are enabled in the repository's `.tflint.hcl` and **SHOULD** remain enabled:

```hcl
# Naming conventions
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Documentation requirements
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

# Type safety
rule "terraform_typed_variables" {
  enabled = true
}

# Code quality
rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

# Version constraints
rule "terraform_module_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

# Structure
rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_workspace_remote" {
  enabled = true
}
```

#### Provider Plugins

Enable provider plugins based on your cloud provider usage:

```hcl
# AWS (uncomment if using AWS)
plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Azure (uncomment if using Azure)
plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Google Cloud (uncomment if using GCP)
plugin "google" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}
```

**Official Documentation:**

- [tflint-ruleset-aws](https://github.com/terraform-linters/tflint-ruleset-aws)
- [tflint-ruleset-azurerm](https://github.com/terraform-linters/tflint-ruleset-azurerm)
- [tflint-ruleset-google](https://github.com/terraform-linters/tflint-ruleset-google)

---

### Rule Customization

#### Disabling Specific Rules

To disable a rule, set `enabled = false`:

```hcl
rule "terraform_standard_module_structure" {
  enabled = false  # Disabled for flat directory structure
}
```

#### Adjusting Rule Severity

Some rules support severity configuration:

```hcl
rule "terraform_deprecated_interpolation" {
  enabled = true
  # Note: severity is controlled by the rule itself, not configurable
}
```

#### Organization-Specific Customizations

For organization-specific rules, consider:

1. **Custom naming patterns:**

   ```hcl
   rule "terraform_naming_convention" {
     enabled = true
     format  = "snake_case"

     # Custom format for specific resources (example)
     custom = "^[a-z][a-z0-9_]*$"
   }
   ```

2. **Module inspection depth:**

   ```hcl
   config {
     call_module_type = "all"  # Inspect all modules, not just local
   }
   ```

---

## Pre-commit Integration

This repository already has Terraform hooks configured in `.pre-commit-config.yaml`. This section documents the configuration and local workflow.

### Recommended Hooks

The following hooks are **RECOMMENDED** and are currently configured:

| Hook | Purpose | Auto-fix |
| --- | --- | --- |
| `terraform_fmt` | Format checking | Yes |
| `terraform_validate` | Syntax validation | No |
| `terraform_tflint` | Linting | No |

#### Additional Optional Hooks

| Hook | Purpose | When to Use |
| --- | --- | --- |
| `terraform_docs` | Auto-generate documentation | When maintaining module READMEs |
| `terraform_tfsec` | Security scanning | When security scanning in pre-commit is required |
| `terraform_checkov` | Compliance scanning | When compliance checks are required |

---

### Updating pre-commit-config.yaml

The repository's current configuration:

```yaml
# Terraform formatting and validation (remove if not using Terraform)
- repo: https://github.com/antonbabenko/pre-commit-terraform
  rev: v1.105.0  # Pin to specific version
  hooks:
    - id: terraform_fmt
    - id: terraform_validate
    - id: terraform_tflint
      args:
        - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl
```

**Official Documentation:** [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform)

#### Hook Ordering

Hooks execute in the order listed. The recommended order is:

1. `terraform_fmt` — Fix formatting first
2. `terraform_validate` — Validate syntax
3. `terraform_tflint` — Lint for best practices

This order ensures that formatting is fixed before validation, and validation passes before linting.

#### Adding terraform-docs Hook

To add automatic documentation generation:

```yaml
- id: terraform_docs
  args:
    - --hook-config=--path-to-file=README.md
    - --hook-config=--add-to-existing-file=true
    - --hook-config=--create-file-if-not-exist=true
```

---

### Local Workflow

#### Installation

```bash
# Install pre-commit globally
pip install pre-commit

# Install hooks in repository
pre-commit install
```

#### Running Hooks Manually

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run specific hook
pre-commit run terraform_fmt --all-files
pre-commit run terraform_tflint --all-files

# Run on staged files only
pre-commit run
```

#### Updating Hook Versions

```bash
# Update all hooks to latest versions
pre-commit autoupdate

# Review changes to .pre-commit-config.yaml
git diff .pre-commit-config.yaml
```

---

### Troubleshooting Pre-commit Hooks

#### Common Issues

| Issue | Cause | Solution |
| --- | --- | --- |
| `terraform_validate` fails | Terraform not initialized | Run `terraform init -backend=false` in each directory |
| `terraform_tflint` fails | TFLint plugins not initialized | Run `tflint --init` |
| Hook times out | Large repository | Increase timeout with `--hook-timeout` |
| Hook skipped | No matching files | Verify file patterns in hook config |

#### Debugging Hook Failures

```bash
# Run with verbose output
pre-commit run --verbose terraform_tflint --all-files

# Show hook configuration
pre-commit show-config
```

#### Bypassing Hooks (Emergency Only)

```bash
# Skip all hooks (not recommended)
git commit --no-verify -m "Emergency commit"
```

> **Warning:** Bypassing hooks should be reserved for emergencies. CI will still enforce these checks.

---

## CI Workflow Design Decisions

This section explains the design decisions that **SHOULD** be documented in the workflow header comment.

### Header Comment Documentation

Every workflow file **SHOULD** include a comprehensive header comment explaining:

1. **Purpose:** What the workflow does
2. **Design Decisions:** Why key choices were made
3. **Template Considerations:** Special handling for template repos
4. **Version Policy:** How tool versions are managed

#### Example Header

```yaml
# Terraform CI Workflow
#
# Purpose: Run format checking, validation, linting, and testing for
# Terraform code in a single consolidated workflow.
#
# Design Decisions:
#
# 1. Single Workflow with Job Dependencies:
#    Combines format, validate, lint, and test into one workflow file using
#    `needs:` for job dependencies. Benefits: all jobs visible in PR checks,
#    simpler branch ruleset config, efficient CI minutes.
#
# 2. Job Dependencies:
#    format → validate → lint (sequential)
#    validate → test (if tests exist)
#    This ensures we don't waste time on later checks if earlier ones fail.
#
# 3. Template Repository Consideration:
#    No path-based filtering. Template repos must test all workflows.
#
# 4. Terraform Version Policy:
#    Pin to specific version (1.6.0) for reproducibility. Update when
#    upstream support changes or new features are needed.
```

---

### Job Dependencies

#### Why Format Before Validate

- **Consistency:** Ensure all code has consistent formatting before validation
- **Cleaner diffs:** Formatting issues don't obscure validation errors
- **Faster feedback:** Formatting check is fast, fails early if needed

#### Why Validate Before Lint

- **Prerequisite:** TFLint assumes valid Terraform syntax
- **Cleaner output:** Validation errors are more fundamental than lint errors
- **Logical progression:** Fix syntax before style

---

### Continue-on-error Usage

#### When to Use `continue-on-error: true`

| Scenario | Recommendation |
| --- | --- |
| Advisory security scans | Use `continue-on-error: true` |
| Secondary scanners | Use `continue-on-error: true` |
| Experimental checks | Use `continue-on-error: true` |
| Core linting/validation | **Never** use `continue-on-error` |

#### Example

```yaml
# Primary security scan - MUST pass
- name: Run tfsec
  uses: aquasecurity/tfsec-action@v1.0.3

# Advisory scan - informational only
- name: Run Checkov (Advisory)
  uses: bridgecrewio/checkov-action@v12
  continue-on-error: true
```

---

### Multiple Terraform Roots

#### Monorepo Considerations

When a repository contains multiple Terraform configurations (monorepo pattern):

1. **Discovery approach:** Find all directories containing `.tf` files
2. **Iterate over directories:** Run init/validate in each
3. **Parallel execution:** Use matrix strategy for large repos

#### Example Discovery Script

```yaml
- name: Find Terraform Directories
  id: find-tf-dirs
  run: |
    # Find all directories containing .tf files
    TF_DIRS=$(find . -name '*.tf' -exec dirname {} \; | sort -u | tr '\n' ' ')
    echo "dirs=${TF_DIRS}" >> $GITHUB_OUTPUT

- name: Validate Each Directory
  run: |
    for dir in ${{ steps.find-tf-dirs.outputs.dirs }}; do
      echo "=== Validating $dir ==="
      cd "$dir"
      terraform init -backend=false
      terraform validate
      cd - > /dev/null
    done
```

#### Matrix Strategy for Large Repos

```yaml
strategy:
  matrix:
    directory: ['modules/vpc', 'modules/ec2', 'environments/prod']

steps:
  - name: Validate ${{ matrix.directory }}
    working-directory: ${{ matrix.directory }}
    run: |
      terraform init -backend=false
      terraform validate
```

---

### Path Filtering

#### Why This Template Avoids Path Filtering

The current `terraform-ci.yml` uses path filtering:

```yaml
on:
  push:
    paths:
      - '**/*.tf'
      - '**/*.tfvars'
      - '.tflint.hcl'
```

However, for template repositories, path filtering **SHOULD NOT** be used because:

1. **Template testing:** All workflows should run to verify template works
2. **Hidden failures:** Path filtering can hide workflow issues
3. **User confusion:** Template users may not understand path filtering behavior

#### Guidance for Non-Template Repos

For non-template repositories, path filtering is **RECOMMENDED** to:

- Reduce unnecessary CI runs
- Speed up feedback for non-Terraform changes
- Conserve CI minutes

```yaml
# Recommended for non-template repos
on:
  push:
    paths:
      - '**/*.tf'
      - '**/*.tfvars'
      - '**/*.tftest.hcl'
      - '.tflint.hcl'
      - '.github/workflows/terraform-ci.yml'
```

---

### Failure Handling

#### Which Jobs Should Fail the Workflow

| Job | Should Fail Workflow | Rationale |
| --- | --- | --- |
| format | Yes | Formatting is required |
| validate | Yes | Valid syntax is required |
| lint | Yes | Best practices are required |
| test | Yes (if tests exist) | Tests must pass |
| security (primary) | Configurable | Depends on security policy |
| security (advisory) | No | Informational only |

#### Configuring Required Jobs in Branch Ruleset

In GitHub branch ruleset settings, configure these jobs as required status checks:

1. `Terraform CI / Format Check`
2. `Terraform CI / Validate`
3. `Terraform CI / Lint (TFLint)`
4. `Terraform CI / Test` (if tests exist)

Security scans can be optional based on team preference.

---

## Integration with Existing Infrastructure

### Auto-fix Workflow Integration

The repository's `auto-fix-precommit.yml` workflow could be extended to support Terraform auto-fixes.

#### Which Checks Can Auto-fix

| Check | Auto-fixable | Tool |
| --- | --- | --- |
| Formatting | Yes | `terraform fmt` |
| Validation errors | No | Manual fix required |
| Lint errors | Some | TFLint can fix some issues |
| Security findings | No | Manual fix required |

#### Potential Auto-fix Addition

The existing auto-fix workflow runs `pre-commit run --all-files`, which includes `terraform_fmt`. No additional configuration is needed for format auto-fixes.

For repositories where TFLint can auto-fix issues, consider:

```yaml
# In auto-fix workflow (if TFLint fixes are desired)
- name: Run TFLint with fixes
  run: tflint --fix --recursive
```

> **Note:** TFLint's `--fix` flag is limited. Most lint issues require manual fixes.

---

### Updates to copilot-instructions.md

When implementing Terraform linting, the following sections in `.github/copilot-instructions.md` should be updated:

#### Linting Configurations Table

Add TFLint to the existing table:

```markdown
| Tool | Configuration File | Purpose |
| --- | --- | --- |
| PSScriptAnalyzer | `.github/linting/PSScriptAnalyzerSettings.psd1` | PowerShell formatting/linting |
| markdownlint | `.markdownlint.jsonc` | Markdown linting |
| TFLint | `.tflint.hcl` | Terraform linting |
```

> **Note:** This is already present in the current `copilot-instructions.md`.

#### Running Linters Section

Add Terraform commands:

**Example Terraform linter commands:**

```bash
terraform fmt -check -recursive
tflint --recursive
```

> **Note:** This is already present in the current `copilot-instructions.md`.

---

### README Update Recommendations

When fully implementing Terraform support, consider updating the README with:

#### Linting Tools Entry

Add a Terraform section to the README:

> **Terraform**
>
> This repository includes Terraform linting via:
>
> - **terraform fmt:** Format checking and auto-formatting
> - **terraform validate:** Configuration validation
> - **TFLint:** Best practice linting with cloud provider plugins
>
> Configuration: `.tflint.hcl`

#### Command Examples Entry

Add Terraform commands to the linters section:

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

---

## Versioning Policy Guidance

### Terraform Version Pinning

#### Recommendation

**SHOULD** pin Terraform version for reproducibility:

```yaml
- uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: "1.6.0"  # Pin specific version
```

#### Version Constraint Options

| Pattern | Example | Use Case |
| --- | --- | --- |
| Exact version | `1.6.0` | Maximum reproducibility |
| Minor range | `~> 1.6.0` | Accept patch updates |
| Major range | `~> 1.6` | Accept minor updates |
| Latest | `latest` | Always newest (not recommended) |

#### When "latest" Is Acceptable

Using `latest` is acceptable **ONLY** for:

- Personal development environments
- Non-critical testing
- Intentionally tracking latest features

Using `latest` is **NOT** acceptable for:

- Production CI pipelines
- Reproducible builds
- Module publishing

### TFLint Version Pinning

The current configuration uses `latest`:

```yaml
- uses: terraform-linters/setup-tflint@v4
  with:
    tflint_version: latest
```

**Recommendation:** Pin to specific version for reproducibility:

```yaml
- uses: terraform-linters/setup-tflint@v4
  with:
    tflint_version: v0.51.1
```

### Pre-commit Hook Version Pinning

The repository follows best practice by pinning pre-commit hook versions:

```yaml
- repo: https://github.com/antonbabenko/pre-commit-terraform
  rev: v1.105.0  # Pinned version
```

**MUST** pin versions in pre-commit configuration for:

- Reproducible behavior
- Controlled updates
- CI consistency

---

## Summary of Recommended Steps

This section provides a clear action plan for implementing Terraform linting in this repository.

### Immediate Actions (Already Complete)

- [x] TFLint configuration file (`.tflint.hcl`) in repository root
- [x] Pre-commit hooks configured for Terraform
- [x] Basic Terraform CI workflow exists

### Recommended Improvements

1. **Update Terraform CI workflow header comments**
   - Add comprehensive design decision documentation
   - Document template repository considerations

2. **Add job dependencies to Terraform CI**
   - Configure `needs:` between format, validate, and lint jobs
   - Ensure format runs before validate, validate before lint

3. **Remove path filtering for template repository**
   - Remove `paths:` filter from `on.push` and `on.pull_request`
   - Run workflow on all changes for template accuracy

4. **Add caching to Terraform CI**
   - Cache Terraform providers
   - Cache TFLint plugins

5. **Consider security scanning**
   - Add tfsec as optional security scan
   - Configure with `continue-on-error: true` initially

6. **Pin tool versions**
   - Pin Terraform version in CI
   - Pin TFLint version in CI

### Implementation Checklist

For reference, here is a checklist of all changes that would fully implement Terraform linting:

- [ ] Update `terraform-ci.yml` with comprehensive header comments
- [ ] Add job dependencies (`needs:`) to workflow
- [ ] Remove path filtering from template workflow
- [ ] Add provider and TFLint plugin caching
- [ ] Pin Terraform and TFLint versions
- [ ] Add optional tfsec security scanning
- [ ] Verify pre-commit hooks work locally
- [ ] Test workflow on sample Terraform code
- [ ] Update README with Terraform linting documentation

### Documentation Maintenance

This guide **SHOULD** be updated when:

- New Terraform linting tools become available
- Tool versions or configurations change significantly
- Repository CI patterns evolve
- Best practices change in the Terraform ecosystem

---

## References

### Official Documentation Links

| Tool | Documentation URL |
| --- | --- |
| Terraform CLI | <https://developer.hashicorp.com/terraform/cli> |
| terraform fmt | <https://developer.hashicorp.com/terraform/cli/commands/fmt> |
| terraform validate | <https://developer.hashicorp.com/terraform/cli/commands/validate> |
| TFLint | <https://github.com/terraform-linters/tflint> |
| setup-terraform Action | <https://github.com/hashicorp/setup-terraform> |
| setup-tflint Action | <https://github.com/terraform-linters/setup-tflint> |
| pre-commit-terraform | <https://github.com/antonbabenko/pre-commit-terraform> |
| Checkov | <https://www.checkov.io/> |
| tfsec | <https://github.com/aquasecurity/tfsec> |
| Terrascan | <https://github.com/tenable/terrascan> |
| Trivy | <https://github.com/aquasecurity/trivy> |

### Related Repository Documentation

| Document | Path |
| --- | --- |
| Repository Constitution | `.github/copilot-instructions.md` |
| Terraform Instructions | `.github/instructions/terraform.instructions.md` |
| TFLint Configuration | `.tflint.hcl` |
| Pre-commit Configuration | `.pre-commit-config.yaml` |
| Terraform CI Workflow | `.github/workflows/terraform-ci.yml` |
| Auto-fix Workflow | `.github/workflows/auto-fix-precommit.yml` |
