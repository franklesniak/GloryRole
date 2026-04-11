---
applyTo: "**/*.tf,**/*.tfvars,**/*.tftest.hcl,**/*.tf.json,**/*.tftpl,**/*.tfbackend"
description: "Terraform coding standards: secure, modular, and well-documented infrastructure as code."
---

# Terraform Writing Style

**Version:** 1.17.20260202.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-02-02
- **Scope:** Defines Terraform coding standards for all `.tf`, `.tfvars`, `.tftest.hcl`, `.tf.json`, `.tftpl`, and `.tfbackend` files in this repository. Covers style, formatting, naming conventions, file organization, variable and output design, resource configuration, module design, refactoring, state management, cross-stack data sharing, security best practices, provider management, testing, and documentation requirements.
- **Related:** [Repository Copilot Instructions](../copilot-instructions.md)

## Table of Contents

- [Keywords](#keywords)
- [About Examples in This Document](#about-examples-in-this-document)
- [Quick Reference Checklist](#quick-reference-checklist)
  - [Code Authoring Guidelines](#code-authoring-guidelines)
- [Executive Summary: Terraform Philosophy](#executive-summary-terraform-philosophy)
- [Terraform Version Requirements](#terraform-version-requirements)
- [Upgrading Terraform Versions](#upgrading-terraform-versions)
- [Formatting and Style](#formatting-and-style)
- [Naming Conventions](#naming-conventions)
  - [Globally Unique Resource Names](#globally-unique-resource-names)
- [File Organization](#file-organization)
- [Variable and Output Design](#variable-and-output-design)
  - [Nullable Variables](#nullable-variables)
  - [Null Value Patterns](#null-value-patterns)
  - [Defensive Attribute Access with try()](#defensive-attribute-access-with-try)
  - [Terraform Cloud Variable Precedence](#terraform-cloud-variable-precedence)
- [Continuous Validation with check Blocks](#continuous-validation-with-check-blocks)
- [Resource Configuration](#resource-configuration-1)
  - [Resource Timeouts](#resource-timeouts)
  - [The terraform_data Resource](#the-terraform_data-resource)
  - [Explicit Dependencies](#explicit-dependencies)
  - [Module-Level depends_on](#module-level-depends_on)
- [Module Design](#module-design-1)
- [Refactoring](#refactoring-1)
- [State Management](#state-management-1)
  - [Terraform Cloud, Enterprise, and Alternative Backends](#terraform-cloud-enterprise-and-alternative-backends)
  - [Terraform Cloud Workspace Configuration](#terraform-cloud-workspace-configuration)
  - [Bootstrapping State Infrastructure](#bootstrapping-state-infrastructure)
  - [Environment Separation Strategies](#environment-separation-strategies)
  - [Resource Targeting](#resource-targeting)
  - [Reviewing Plan Output](#reviewing-plan-output)
  - [State Backup and Recovery](#state-backup-and-recovery)
- [Cross-Stack Data Sharing](#cross-stack-data-sharing-1)
- [Provider Management](#provider-management-1)
  - [Provider Aliasing](#provider-aliasing)
  - [Module Provider Configuration with configuration_aliases](#module-provider-configuration-with-configuration_aliases)
  - [Cross-Account and Service Account Patterns](#cross-account-and-service-account-patterns)
- [Security Best Practices](#security-best-practices)
  - [Sensitive Values in Meta-Arguments](#sensitive-values-in-meta-arguments)
  - [Ephemeral Values](#ephemeral-values)
  - [Sensitive Output Exposure in CLI](#sensitive-output-exposure-in-cli)
- [Testing with Terraform Test](#testing-with-terraform-test)
- [Documentation Standards](#documentation-standards)
  - [Error Message Best Practices](#error-message-best-practices)
- [Common Anti-Patterns to Avoid](#common-anti-patterns-to-avoid)
- [Troubleshooting Common Issues](#troubleshooting-common-issues)
- [Pre-commit Discipline for Terraform](#pre-commit-discipline-for-terraform)
- ["Done" Definition for Terraform Changes](#done-definition-for-terraform-changes)
- [Related Documentation](#related-documentation)
- [Scope Exceptions & Deviations from Standards](#scope-exceptions--deviations-from-standards)
- [Changelog](#changelog)
- [Glossary](#glossary)

## Keywords

The key words "**MUST**", "**MUST NOT**", "**REQUIRED**", "**SHALL**", "**SHALL NOT**", "**SHOULD**", "**SHOULD NOT**", "**RECOMMENDED**", "**MAY**", and "**OPTIONAL**" in this document are to be interpreted as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

- **MUST** / **REQUIRED** / **SHALL** — Absolute requirement. Non-negotiable.
- **MUST NOT** / **SHALL NOT** — Absolute prohibition.
- **SHOULD** / **RECOMMENDED** — Strong recommendation. Valid reasons may exist to deviate, but implications must be understood.
- **SHOULD NOT** / **NOT RECOMMENDED** — Strong discouragement. Valid reasons may exist to do otherwise, but implications must be understood.
- **MAY** / **OPTIONAL** — Truly optional. Implementations can choose to include or omit.

> **Applicability rule:** Requirements in this document apply **when their scope is present**. For example, **module** requirements apply only when you maintain reusable modules; **test** requirements apply only when you add Terraform tests; **root module** requirements apply only when a root configuration exists. When a scoped construct exists, all associated **MUST/SHOULD** requirements are expected to be followed.

## About Examples in This Document

All code examples in this document are illustrative. Resource names, bucket names, regions,
account IDs, project IDs, and other configuration values are examples only and do not represent
actual infrastructure.

When applying these patterns to your infrastructure:

- Replace example resource names (e.g., `acme-corp-terraform-state`) with names following your organization's conventions
- Select regions appropriate for your latency, compliance, and cost requirements
- Use account IDs, project IDs, and subscription IDs from your cloud environment
- Adjust instance types, storage sizes, and other parameters for your workload

Examples use common conventions (e.g., `us-east-1`, `prod`, `main`) for familiarity. These choices
are not recommendations for your specific use case.

## Quick Reference Checklist

This checklist provides a quick reference for both human developers and LLMs (like GitHub Copilot) to follow the Terraform style guidelines. Each item includes a scope tag indicating applicability:

- **[All]** — Applies to all Terraform files
- **[Module]** — Applies when developing reusable modules
- **[Root]** — Applies to root configurations (deployments)
- **[Test]** — Applies to test files (`.tftest.hcl`)

> **Scope reminder:** Items tagged **[Module]**, **[Root]**, or **[Test]** are mandatory **when those constructs are present**. If the construct does not exist in your repo, the requirement is not yet applicable.

### Formatting and Style

- **[All]** Code **MUST** pass `terraform fmt` without modifications → [terraform fmt Compliance](#terraform-fmt-compliance)
- **[All]** Code **MUST** use 2 spaces for indentation, never tabs → [Indentation Rules](#indentation-rules)
- **[All]** Files **MUST** use UTF-8 encoding → [File Encoding](#file-encoding)
- **[All]** Files **MUST** end with a single newline → [File Endings](#file-endings)
- **[All]** Lines **SHOULD NOT** exceed 120 characters except for long strings or URLs → [Line Length](#line-length)
- **[All]** Blank lines **MUST** be completely empty (no whitespace) → [Blank Lines](#blank-lines)
- **[All]** Comments **MUST** use `#` for single-line; `/* */` **MAY** be used for multi-line → [Comment Style](#comment-style)

### Naming Conventions

- **[All]** Resources **MUST** use `snake_case` names → [Resource Naming](#resource-naming)
- **[All]** Variables **MUST** use `snake_case` with descriptive names → [Variable Naming](#variable-naming)
- **[All]** Outputs **MUST** use `snake_case` matching resource attribute patterns → [Output Naming](#output-naming)
- **[Module]** Module directory names **MUST** use hyphen-separated lowercase words → [Module Naming](#module-naming)
- **[All]** Data sources **MUST** be prefixed with purpose when multiple exist → [Data Source Naming](#data-source-naming)
- **[All]** Locals **MUST** use `snake_case` with descriptive names → [Local Value Naming](#local-value-naming)
- **[All]** Boolean variables **SHOULD** use `enable_*`, `is_*`, or `has_*` prefixes → [Boolean Naming Patterns](#boolean-naming-patterns)
- **[All]** Globally unique resource names **SHOULD** include random suffixes or organization prefixes → [Globally Unique Resource Names](#globally-unique-resource-names)

### File Organization

- **[All]** Every Terraform directory **MUST** have a `versions.tf` file → [Version Constraints File](#version-constraints-file)
- **[All]** Input variables **MUST** be in `variables.tf` → [Standard File Organization](#standard-file-organization)
- **[All]** Outputs **MUST** be in `outputs.tf` → [Standard File Organization](#standard-file-organization)
- **[Root]** Root modules **MUST** have a `providers.tf` file → [Provider Configuration File](#provider-configuration-file)
- **[Root]** Root modules **MUST** have a `backend.tf` or backend configuration → [Backend Configuration](#backend-configuration)
- **[Module]** Modules **MUST** include a `README.md` → [Module README Requirements](#module-readme-requirements)
- **[Module]** Modules **SHOULD** include `examples/` directory → [Module Examples](#module-examples)
- **[Module]** Modules **SHOULD** include `tests/` directory → [Module Tests](#module-tests)
- **[All]** Template files **SHOULD** use `.tftpl` extension → [Template Files (.tftpl)](#template-files-tftpl)
- **[All]** Template files **SHOULD** be placed in a `templates/` subdirectory → [Template Files (.tftpl)](#template-files-tftpl)
- **[Root]** Large root modules **MAY** split resources into domain-specific files → [Splitting Large Configurations](#splitting-large-configurations)

### Variable and Output Design

- **[All]** Variables **MUST** include a `description` → [Variable Documentation Requirements](#variable-documentation-requirements)
- **[All]** Variables **MUST** include explicit `type` constraint → [Variable Type Constraints](#variable-type-constraints)
- **[All]** Optional variables **MUST** have a `default` value → [Variable Defaults](#variable-defaults)
- **[All]** Sensitive variables **MUST** be marked with `sensitive = true` → [Sensitive Variable Marking](#sensitive-variable-marking)
- **[All]** Variables with constrained values **SHOULD** use `validation` blocks → [Variable Validation](#variable-validation)
- **[All]** Outputs **MUST** include a `description` → [Output Documentation Requirements](#output-documentation-requirements)
- **[All]** Sensitive outputs **MUST** be marked with `sensitive = true` → [Sensitive Output Marking](#sensitive-output-marking)
- **[All]** Variables **SHOULD** explicitly set `nullable` to document null-handling behavior → [Nullable Variables](#nullable-variables)
- **[All]** `try()` **SHOULD** be used for defensive access to attributes that may not exist → [Defensive Attribute Access with try()](#defensive-attribute-access-with-try)

### Continuous Validation

- **[All]** `check` blocks **MAY** be used for continuous validation → [Continuous Validation with check Blocks](#continuous-validation-with-check-blocks)

### Resource Configuration

- **[All]** Meta-arguments **MUST** appear first in resource blocks → [Meta-Argument Ordering](#meta-argument-ordering)
- **[All]** Required arguments **MUST** appear before optional arguments → [Argument Ordering](#argument-ordering)
- **[All]** Nested blocks **MUST** appear last in resource blocks → [Nested Block Placement](#nested-block-placement)
- **[All]** Resources **MUST** include required tags → [Required Tags](#required-tags)
- **[Root]** Provider-level default tags **SHOULD** be configured → [Default Tags Configuration](#default-tags-configuration)
- **[All]** Local values **SHOULD** be used for computed or merged tags → [Local Tags Pattern](#local-tags-pattern)
- **[All]** `precondition` blocks **SHOULD** validate assumptions before resource creation → [Resource Preconditions](#resource-preconditions)
- **[All]** `postcondition` blocks **SHOULD** validate resource state after creation → [Resource Postconditions](#resource-postconditions)
- **[All]** `depends_on` **SHOULD** be avoided unless dependencies are not inferable → [Explicit Dependencies](#explicit-dependencies)
- **[All]** `for_each` **SHOULD** be preferred over `count` for collections → [for_each vs count](#for_each-vs-count)
- **[All]** Dynamic blocks **SHOULD** be used sparingly → [Dynamic Blocks](#dynamic-blocks)
- **[All]** `prevent_destroy` **SHOULD** be used for critical resources → [Lifecycle Block Options](#lifecycle-block-options)
- **[All]** `ignore_changes` **SHOULD** be used for attributes managed outside Terraform → [Lifecycle Block Options](#lifecycle-block-options)
- **[All]** Custom `timeouts` blocks **MAY** be used for long-running resource operations → [Resource Timeouts](#resource-timeouts)

### Module Design

- **[Module]** Modules **MUST** have a single, well-defined responsibility → [Single Responsibility](#single-responsibility)
- **[Module]** Modules **MUST** specify required Terraform and provider versions → [Module Version Constraints](#module-version-constraints)
- **[Module]** Module inputs **MUST** use consistent naming across modules → [Module Interface Design](#module-interface-design)
- **[Module]** Required module variables **SHOULD** be minimized → [Minimal Required Inputs](#minimal-required-inputs)
- **[Module]** Complex inputs **SHOULD** use object types with documented structure → [Complex Input Types](#complex-input-types)
- **[Module]** Modules **SHOULD** expose only necessary outputs → [Module Output Design](#module-output-design)
- **[Module]** Published modules **MUST** use semantic versioning → [Module Versioning](#module-versioning)
- **[Module]** Modules accepting multiple provider configurations **MUST** use `configuration_aliases` → [Module Provider Configuration with configuration_aliases](#module-provider-configuration-with-configuration_aliases)
- **[All]** Module-level `depends_on` **SHOULD** be avoided unless implicit dependencies are insufficient → [Module-Level depends_on](#module-level-depends_on)

### Refactoring

- **[All]** Resource renames **MUST** use `moved` blocks instead of manual state commands → [Refactoring with Moved Blocks](#refactoring-with-moved-blocks)
- **[All]** Existing infrastructure imports **SHOULD** use `import` blocks instead of CLI commands → [Importing Resources with Import Blocks](#importing-resources-with-import-blocks)
- **[All]** Resources removed from management **SHOULD** use `removed` blocks → [Removing Resources from State with Removed Blocks](#removing-resources-from-state-with-removed-blocks)
- **[All]** Direct state manipulation commands **SHOULD** be avoided → [State Manipulation Commands](#state-manipulation-commands)

### State Management

- **[Root]** Root modules **MUST** configure a remote backend → [Remote Backend Configuration](#remote-backend-configuration)
- **[Root]** State files **MUST** be encrypted at rest → [State Encryption](#state-encryption)
- **[Root]** State locking **MUST** be enabled → [State Locking](#state-locking)
- **[All]** Local state files **MUST NOT** be used in production → [No Local State in Production](#no-local-state-in-production)
- **[All]** State files **MUST NOT** be committed to version control → [State File Exclusion](#state-file-exclusion)
- **[All]** `terraform apply -target` **SHOULD NOT** be used in normal workflows → [Resource Targeting](#resource-targeting)
- **[Root]** New state storage infrastructure **SHOULD** follow the bootstrap workflow → [Bootstrapping State Infrastructure](#bootstrapping-state-infrastructure)
- **[All]** Plan output **MUST** be reviewed for unexpected destroys or replacements before applying → [Reviewing Plan Output](#reviewing-plan-output)
- **[Root]** State storage buckets **MUST** have versioning enabled for production use → [State Versioning Requirements](#state-versioning-requirements)
- **[All]** Manual state backups **SHOULD** be created before risky operations → [Manual State Backup](#manual-state-backup)
- **[All]** State files **MUST NOT** be manually edited → [Common State Problems and Recovery](#common-state-problems-and-recovery)

### Cross-Stack Data Sharing

- **[Root]** Cross-stack data **SHOULD** be shared via cloud-native parameter stores → [Cross-Stack Data Sharing](#cross-stack-data-sharing)
- **[Root]** `terraform_remote_state` **MAY** be used with documented coupling implications → [Cross-Stack Data Sharing](#cross-stack-data-sharing)
- **[All]** Secrets **MUST NOT** be shared via parameter stores or remote state → [Cross-Stack Data Sharing](#cross-stack-data-sharing)

### Provider Management

- **[All]** Provider versions **MUST** be constrained → [Provider Version Constraints](#provider-version-constraints)
- **[All]** `.terraform.lock.hcl` **MUST** be committed to version control → [Lock File Management](#lock-file-management)
- **[All]** Pessimistic constraint operator (`~>`) **SHOULD** be used for providers → [Pessimistic Constraints](#pessimistic-constraints)
- **[All]** Multi-region or multi-account deployments **MUST** use provider aliases → [Provider Aliasing](#provider-aliasing)

### Security

- **[All]** Secrets **MUST NOT** appear in `.tf` files → [Secret Management](#secret-management)
- **[All]** Secrets **MUST NOT** have default values → [No Secret Defaults](#no-secret-defaults)
- **[All]** Secrets **MUST** be provided via environment variables or secret managers → [Approved Secret Patterns](#approved-secret-patterns)
- **[Root]** State backends **MUST** enable encryption → [State Security](#state-security)
- **[All]** IAM policies **MUST** follow least-privilege principles → [Least-Privilege Principles](#least-privilege-principles)
- **[All]** Wildcard actions **SHOULD NOT** be used in IAM policies → [IAM Policy Guidelines](#iam-policy-guidelines)
- **[All]** Sensitive values **MUST NOT** be used in `for_each` or `count` expressions → [Sensitive Values in Meta-Arguments](#sensitive-values-in-meta-arguments)
- **[All]** Sensitive outputs **MUST NOT** be logged in CI/CD pipelines → [Sensitive Output Exposure in CLI](#sensitive-output-exposure-in-cli)

### Testing

- **[Test]** Test files **MUST** use `.tftest.hcl` extension → [Test File Naming](#test-file-naming)
- **[Test]** Test files **SHOULD** be in a `tests/` directory → [Test File Location](#test-file-location)
- **[Test]** Tests **MUST** include at least one `run` block → [Test Structure](#test-structure)
- **[Test]** Each `run` block **MUST** include at least one `assert` → [Test Assertions](#test-assertions)
- **[Test]** Variable validation **SHOULD** be tested → [Testing Variable Validation](#testing-variable-validation)
- **[Test]** Unit tests **SHOULD** use `command = plan` → [Unit Tests](#unit-tests)
- **[Test]** Integration tests **MAY** use `command = apply` → [Integration Tests](#integration-tests)
- **[Module]** Modules **SHOULD** include corresponding Terraform tests → [Module Tests](#module-tests)
- **[Test]** Mock providers **SHOULD** be used for unit tests → [Mock Providers](#mock-providers)
- **[Test]** Negative test cases **SHOULD** use `expect_failures` → [Testing Variable Validation](#testing-variable-validation)

### Documentation

- **[Module]** Modules **MUST** have a `README.md` with usage examples → [Module README Requirements](#module-readme-requirements)
- **[All]** Inline comments **SHOULD** explain "why," not "what" → [Inline Comment Conventions](#inline-comment-conventions)
- **[All]** TODO comments **SHOULD** include username and context → [TODO Comment Format](#todo-comment-format)
- **[All]** Error messages in validation blocks **SHOULD** be actionable and reference valid options or acceptable ranges → [Error Message Best Practices](#error-message-best-practices)

### Code Authoring Guidelines

The following guidelines apply to all code authors, including human developers and AI assistants such as GitHub Copilot:

- **[All]** Authors **MUST NOT** invent providers, modules, or placeholder values without explicit confirmation of requirements
- **[All]** Authors **MUST** ask for or verify missing required information (e.g., `bucket`, `region`, `project_id`) rather than inserting assumptions
- **[All]** Authors **MUST NOT** include secrets, API keys, tokens, or hardcoded sensitive information in code
- **[All]** Authors **SHOULD** default to minimal, reproducible, and well-documented code
- **[All]** Authors **MUST** only modify backend configuration when explicitly required
- **[All]** Authors **SHOULD NOT** assume a default cloud provider; when the provider is not specified, authors **SHOULD** use provider-agnostic examples and document that provider selection is required
- **[All]** Authors **SHOULD** include `description` for all variables and outputs, and use `sensitive = true` as appropriate
- **[All]** Authors **MUST NOT** modify lock files (`.terraform.lock.hcl`) or commit state unless explicitly required

## Executive Summary: Terraform Philosophy

This repository approaches Terraform as **infrastructure as code** with the same rigor applied to application code. The following principles guide all Terraform development:

- **Deterministic and reproducible:** Infrastructure changes **MUST** produce predictable, repeatable results. The same configuration **MUST** produce the same infrastructure across environments.

- **Security-first:** Secrets **MUST NEVER** appear in code or state unencrypted. Least-privilege **MUST** be the default for all IAM policies and resource access controls.

- **Modular and reusable:** Common infrastructure patterns **SHOULD** be extracted into versioned modules with well-defined interfaces. Modules **MUST** be designed for reuse across projects.

- **Well-documented:** Every variable, output, and module **MUST** be documented. Documentation is not optional—it is a first-class deliverable.

- **Testable:** Infrastructure **SHOULD** be validated with automated tests before deployment. Terraform's native test framework enables validation of configuration logic.

- **Version-controlled:** All Terraform code, including lock files, **MUST** be version-controlled. State files **MUST** be stored remotely with encryption and locking.

The coding standards in this document enforce these principles through specific, actionable requirements.

> **Provider-Agnostic Guidance:** This document includes parallel examples for AWS, Azure, and GCP where applicable. All style rules and best practices are **provider-agnostic**. Users **MAY** remove examples for providers they do not use. The principles of naming, structure, security, and documentation apply equally across all providers.

---

## Terraform Version Requirements

The following table summarizes Terraform version requirements for features referenced in this document:

| Feature | Minimum Terraform Version |
| --- | --- |
| `moved` blocks | 1.1.0 |
| `nullable` variable attribute | 1.1.0 |
| `precondition` / `postcondition` blocks | 1.2.0 |
| `replace_triggered_by` lifecycle argument | 1.2.0 |
| `optional()` type constraint modifier | 1.3.0 |
| `terraform_data` resource | 1.4.0 |
| `check` blocks | 1.5.0 |
| `import` blocks | 1.5.0 |
| Native test framework (`terraform test`) | 1.6.0 |
| `removed` blocks | 1.7.0 |
| `mock_provider` in tests | 1.7.0 |
| `ephemeral` values | 1.10.0 |

> **Note:** Examples in this document assume Terraform 1.10.0 or later unless otherwise noted. Users on older Terraform versions should verify feature availability before adopting specific patterns.

---

## Upgrading Terraform Versions

This section provides guidance for safely upgrading Terraform versions, including preparation steps, upgrade procedures, and rollback strategies.

### Version Upgrade Checklist

Before upgrading Terraform, complete the following checklist:

- [ ] Read the [Terraform Changelog](https://github.com/hashicorp/terraform/blob/main/CHANGELOG.md) for breaking changes
- [ ] Create a state backup before upgrading
- [ ] Test the upgrade in a non-production environment first
- [ ] Update `.terraform.lock.hcl` after upgrading
- [ ] Run `terraform plan` and verify no unexpected changes
- [ ] Update CI/CD pipeline Terraform version after validation
- [ ] Update `required_version` constraint if needed

### Pre-Upgrade Preparation

Before upgrading, document your current state and create recovery points:

```bash
# 1. Backup current state
terraform state pull > terraform.tfstate.backup

# 2. Document current version
terraform version

# 3. Review current plan (baseline)
terraform plan -out=pre-upgrade.tfplan
```

> **Note:** Store the backup and plan output in a secure location outside the working directory. These files **MUST NOT** be committed to version control as they may contain sensitive information.

### Upgrade Process

The upgrade process varies based on the scope of the version change.

#### Patch and Minor Upgrades (e.g., 1.7.0 → 1.7.5 or 1.7.0 → 1.8.0)

Patch and minor version upgrades are generally safe:

1. Update the Terraform binary to the new version
2. Run `terraform init -upgrade` to update provider dependencies
3. Run `terraform plan` and compare output to your pre-upgrade baseline
4. Verify no unexpected changes appear in the plan
5. If the plan is clean, proceed with normal operations

#### Major Version Upgrades (e.g., 1.x → 2.x, when applicable)

Major version upgrades require additional care:

1. Read the official upgrade guide for the specific version transition
2. Review the changelog for all breaking changes and deprecated features
3. Update the Terraform binary to the new version
4. Run `terraform init -upgrade` to update provider lock file
5. Address any deprecation warnings or errors
6. Update configuration for any removed or changed features
7. Run `terraform plan` and carefully review all changes
8. Test thoroughly in a non-production environment before production deployment

### Lock File Updates

After upgrading Terraform, regenerate the `.terraform.lock.hcl` file to ensure all platforms used by your team and CI/CD systems are covered:

```bash
# Regenerate lock file for all platforms
terraform providers lock \
  -platform=linux_amd64 \
  -platform=linux_arm64 \
  -platform=darwin_amd64 \
  -platform=darwin_arm64 \
  -platform=windows_amd64 \
  -platform=windows_arm64

# Commit the updated lock file
git add .terraform.lock.hcl
git commit -m "chore: Update provider lock file for Terraform X.Y.Z"
```

### CI/CD Considerations

When managing Terraform versions in CI/CD pipelines:

- **Pin Terraform versions:** Use explicit version pinning in CI workflows for reproducibility
- **Test in branches first:** Test new Terraform versions in a feature branch before updating main/production pipelines
- **Update after local validation:** Update the version in workflow files **after** successful local validation

**Example GitHub Actions workflow snippet:**

```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: "1.7.0"  # Pin to specific version
```

### Rollback Procedure

If issues occur after upgrading Terraform, follow this rollback procedure:

1. **Restore the previous Terraform binary version:**
   - Use your version manager to switch back (e.g., `tfenv use 1.6.0`)
   - Or download and install the previous version manually

2. **Restore state if modified:**
   - If the new Terraform version modified state, restore from your backup:

     ```bash
     terraform state push terraform.tfstate.backup
     ```

     > **Warning:** `terraform state push` overwrites the remote state. Ensure no other operations are in progress and that you have verified the backup contents before pushing.

3. **Regenerate lock file:**
   - Run `terraform providers lock` with the previous Terraform version

4. **Document the issue:**
   - Record what went wrong for future reference
   - Consider opening an issue on the Terraform repository if you encountered a bug

### Version Managers

Using a version manager simplifies switching between Terraform versions and ensures team consistency:

**tfenv:**

```bash
# Install a specific version
tfenv install 1.7.0

# Use a specific version
tfenv use 1.7.0

# List installed versions
tfenv list
```

**asdf:**

```bash
# Add Terraform plugin (one-time)
asdf plugin add terraform

# Install a specific version
asdf install terraform 1.7.0

# Set local version for a project
asdf local terraform 1.7.0
```

> **Note:** Version specification files (`.terraform-version` for tfenv or `.tool-versions` for asdf) **MAY** be committed to the repository to ensure team consistency. If committed, these files **SHOULD** be updated as part of the version upgrade process.

### Version Upgrade Requirements Summary

The following requirements apply to Terraform version upgrades:

- Version upgrades **MUST** be tested in non-production environments first
- State **SHOULD** be backed up before any version upgrade
- `.terraform.lock.hcl` **MUST** be updated and committed after version changes
- Major version upgrades **MUST** include review of the official upgrade guide

---

## Formatting and Style

### terraform fmt Compliance

All Terraform code **MUST** pass `terraform fmt` without modifications. This is non-negotiable.

**Verification command:**

```bash
terraform fmt -check -recursive
```

**Auto-format command:**

```bash
terraform fmt -recursive
```

**Pre-commit integration:**

```yaml
- repo: https://github.com/antonbabenko/pre-commit-terraform
  rev: v1.105.0
  hooks:
    - id: terraform_fmt
```

### Indentation Rules

- Code **MUST** use 2 spaces for indentation
- Tabs **MUST NOT** be used
- Nested blocks **MUST** maintain consistent indentation
- Alignment of `=` signs is handled automatically by `terraform fmt`

**Compliant:**

```hcl
resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name        = var.instance_name
    Environment = var.environment
  }
}
```

### File Encoding

All Terraform files **MUST** use UTF-8 encoding without BOM (Byte Order Mark).

### File Endings

All files **MUST** end with a single newline character. Trailing blank lines **MUST NOT** be present.

### Line Length

Lines **SHOULD NOT** exceed 120 characters. Exceptions are permitted for:

- Long strings that cannot be reasonably split
- URLs in comments or string values
- Complex expressions where splitting reduces readability

### Blank Lines

Blank lines **MUST** be completely empty—they **MUST NOT** contain any whitespace characters (spaces or tabs).

Use blank lines to:

- Separate logical sections within a file
- Separate resource blocks
- Separate groups of related arguments within a block

### Comment Style

**Single-line comments:**

Use `#` for single-line comments. Comments **SHOULD** be placed on their own line above the code they describe.

```hcl
# Enable encryption to meet compliance requirements
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  # ...
}
```

**Multi-line comments:**

Use `/* */` sparingly for multi-line explanations when a single `#` comment is insufficient.

```hcl
/*
 * This security group allows inbound traffic from the corporate VPN.
 * CIDR ranges are managed by the network team and should not be
 * modified without their approval.
 */
resource "aws_security_group" "vpn_access" {
  # ...
}
```

### JSON Configuration Files (.tf.json)

Terraform supports JSON syntax for configuration files using the `.tf.json` extension. When using JSON configuration:

- `.tf.json` files **MUST** be valid JSON and **SHOULD** be consistently formatted
- JSON files **SHOULD** use 2 spaces for indentation to match HCL conventions
- JSON files **SHOULD** be validated and formatted using standard JSON tools such as `jq`, `prettier`, or IDE-integrated formatters
- JSON configuration **SHOULD** be reserved for programmatically generated Terraform code; hand-written configuration **SHOULD** use HCL (`.tf`) format for readability

**Validation command:**

```bash
# Validate JSON syntax
jq empty *.tf.json

# Format JSON files with jq
jq '.' input.tf.json > formatted.tf.json

# Format with prettier (if available)
prettier --write "*.tf.json"
```

**Note:** `terraform fmt` does not format `.tf.json` files. Use external JSON formatting tools as part of your pre-commit or CI workflow.

### Template File Formatting (.tftpl)

Template files (`.tftpl`) are processed by the `templatefile()` function and generate dynamic content. Formatting expectations for template files:

- Template files **MUST** use UTF-8 encoding
- Template files **MUST** end with a single newline
- Template files **SHOULD** use Unix-style line endings (LF) for cross-platform compatibility
- Template variables **SHOULD** be documented at the top of the file using comments appropriate to the output format
- Terraform template directives (`%{ ... }`, `${ ... }`) **SHOULD** be clearly formatted for readability
- When generating structured output (JSON, YAML), the template **SHOULD** produce valid, well-formatted output

**Comment conventions by output type:**

| Output Format | Comment Style | Example |
| --- | --- | --- |
| Shell scripts | `#` comments | `# Variable: environment (string)` |
| JSON | Document in separate header or external docs | N/A (JSON has no comments) |
| YAML | `#` comments | `# Variable: app_name (string)` |
| XML | `<!-- -->` comments | `<!-- Variable: config_value (string) -->` |

**Validation:**

- Template syntax errors are caught at `terraform plan` time when `templatefile()` is evaluated
- For templates generating JSON/YAML, validate the rendered output format as part of testing
- Use Terraform tests to verify template output for critical templates

---

## Naming Conventions

### Resource Naming

Resources **MUST** use `snake_case` for names. Names **SHOULD** be descriptive and indicate purpose.

| Resource Type | Naming Pattern | Example |
| --- | --- | --- |
| Primary/main resource | `main` or descriptive name | `aws_instance.main` |
| Multiple of same type | Purpose-based suffix | `aws_instance.web_server` |
| Associated resources | Parent reference | `aws_security_group.web_server` |

**Anti-patterns to avoid:**

| Bad | Good | Reason |
| --- | --- | --- |
| `aws_instance.this` | `aws_instance.main` | "this" is not descriptive |
| `aws_instance.instance1` | `aws_instance.primary` | Numeric suffixes are meaningless |
| `aws_instance.MyInstance` | `aws_instance.my_instance` | Must be snake_case |
| `aws_instance.i` | `aws_instance.web_server` | Single-letter names lack meaning |

### Variable Naming

Variables **MUST** use `snake_case` and **MUST** be descriptive.

| Category | Pattern | Example |
| --- | --- | --- |
| Simple values | `<noun>` or `<adjective>_<noun>` | `instance_type`, `environment` |
| Lists/Sets | Plural nouns | `subnet_ids`, `security_group_ids` |
| Maps | `<noun>_map` or descriptive | `tags`, `instance_settings` |
| Booleans | `enable_*`, `is_*`, `has_*` | `enable_monitoring`, `is_public` |
| Resource references | `<resource>_id` or `<resource>_arn` | `vpc_id`, `role_arn` |

**Compliant variable names:**

```hcl
variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "enable_monitoring" {
  description = "Enable CloudWatch detailed monitoring"
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "List of subnet IDs for deployment"
  type        = list(string)
}
```

### Output Naming

Outputs **MUST** use `snake_case` and **SHOULD** follow the pattern of the attribute being exposed.

| Output Type | Pattern | Example |
| --- | --- | --- |
| Resource ID | `<resource>_id` | `instance_id`, `vpc_id` |
| Resource ARN | `<resource>_arn` | `role_arn`, `bucket_arn` |
| Resource name | `<resource>_name` | `bucket_name`, `cluster_name` |
| Endpoints/URLs | `<resource>_endpoint` | `rds_endpoint`, `api_endpoint` |
| Collections | Plural form | `instance_ids`, `subnet_ids` |

### Module Naming

Module directory names **MUST** use hyphen-separated lowercase words.

**Compliant:**

```text
modules/
├── vpc-network/
├── ec2-instance/
├── rds-database/
└── s3-bucket/
```

**Non-compliant:**

```text
modules/
├── VpcNetwork/        # PascalCase
├── ec2_instance/      # snake_case
└── rdsdatabase/       # No separation
```

### Data Source Naming

When multiple data sources of the same type exist, they **MUST** be prefixed with their purpose.

**Single data source:**

```hcl
data "aws_ami" "amazon_linux" {
  # ...
}
```

**Multiple data sources:**

```hcl
data "aws_ami" "web_server" {
  # ...
}

data "aws_ami" "database_server" {
  # ...
}
```

### Local Value Naming

Local values **MUST** use `snake_case` with descriptive names.

```hcl
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }

  instance_name = "${var.project_name}-${var.environment}"
}
```

### Boolean Naming Patterns

Boolean variables and locals **SHOULD** use these prefixes:

| Prefix | Use Case | Example |
| --- | --- | --- |
| `enable_*` | Feature flags | `enable_monitoring`, `enable_encryption` |
| `is_*` | State checks | `is_public`, `is_production` |
| `has_*` | Presence checks | `has_custom_domain`, `has_ssl_certificate` |

### Globally Unique Resource Names

Some cloud resources require globally unique names across all customers. Attempting to create these resources with simple, predictable names often results in `409 Conflict`, `BucketAlreadyExists`, or similar errors.

#### Resources Requiring Globally Unique Names

| Provider | Resources |
| --- | --- |
| **AWS** | S3 buckets, some IAM resources (roles with path-based ARNs) |
| **Azure** | Storage Accounts, Key Vaults, App Services, Cosmos DB accounts |
| **GCP** | GCS buckets, project IDs, Cloud SQL instances |

#### Recommended Patterns

**Pattern 1: Random suffix using `random_id`:**

Use the `random_id` resource to generate a unique suffix that remains stable across applies:

**AWS Example:**

```hcl
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-${var.environment}-${random_id.bucket_suffix.hex}"
}
```

**Azure Example:**

```hcl
resource "random_id" "storage_suffix" {
  byte_length = 4
}

resource "azurerm_storage_account" "main" {
  # Azure Storage Account names must be 3-24 characters, lowercase alphanumeric only
  name                     = "st${var.project_short}${random_id.storage_suffix.hex}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

**GCP Example:**

```hcl
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "main" {
  name     = "${var.project_name}-${var.environment}-${random_id.bucket_suffix.hex}"
  location = var.region
}
```

**Pattern 2: Organization prefix:**

For organizations with registered domain names, use a reversed domain prefix:

```hcl
locals {
  # Produces: com-example-myproject-prod
  globally_unique_prefix = "${replace(var.organization_domain, ".", "-")}-${var.project_name}-${var.environment}"
}

resource "aws_s3_bucket" "main" {
  bucket = local.globally_unique_prefix
}
```

#### When to Use Each Pattern

| Pattern | Use Case |
| --- | --- |
| Random suffix | Default choice for most projects; provides uniqueness without organizational coordination |
| Organization prefix | When naming convention consistency across an organization is required |
| Combination | High-assurance uniqueness: `${org_prefix}-${project}-${random_suffix}` |

#### Lifecycle Considerations

Random suffixes are generated once and stored in state. The `random_id` resource is stable by default—it only regenerates when its inputs change. For explicit control over regeneration, use the `keepers` argument:

```hcl
resource "random_id" "bucket_suffix" {
  byte_length = 4

  # Regenerate only when project_name changes
  keepers = {
    project_name = var.project_name
  }
}
```

> **Warning:** If you lose the Terraform state containing the `random_id`, the suffix cannot be recovered, and new resources will be created with a different suffix on the next apply.

---

## File Organization

### Standard File Organization

Standard file organization for Terraform projects:

| File | Purpose | Requirement |
| --- | --- | --- |
| `main.tf` | Primary resource definitions | MUST |
| `variables.tf` | Input variable declarations | MUST |
| `outputs.tf` | Output value declarations | MUST |
| `providers.tf` | Provider configuration | MUST (root modules) |
| `versions.tf` | Version constraints | MUST |
| `locals.tf` | Local value definitions | MAY |
| `data.tf` | Data source definitions | MAY |
| `backend.tf` | Backend configuration | MUST (root modules) |

#### Splitting Large Configurations

For large root modules with many resources, the `main.tf` file **MAY** be split into domain-specific files to improve readability and maintainability:

| File | Purpose | When to Use |
| --- | --- | --- |
| `network.tf` | VPC, subnets, route tables, security groups | When networking resources exceed ~100 lines |
| `compute.tf` | EC2 instances, ASGs, Lambda functions | When compute resources are distinct from other domains |
| `storage.tf` | S3 buckets, EBS volumes, RDS instances | When storage configuration is substantial |
| `iam.tf` | IAM roles, policies, instance profiles | When IAM configuration is complex |

**Guidelines for splitting:**

- Split by **logical domain**, not by resource type
- Keep related resources together (e.g., an EC2 instance and its security group)
- The `main.tf` file remains the default for simple configurations
- Variable declarations **MUST** remain in `variables.tf` regardless of how resources are split

This approach is **RECOMMENDED** when `main.tf` exceeds 300-400 lines or when multiple team members frequently edit the same file.

### Version Constraints File

Every Terraform directory **MUST** have a `versions.tf` file with Terraform and provider version constraints:

**AWS Example:**

```hcl
# versions.tf

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

**Azure Example:**

```hcl
# versions.tf

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
```

**GCP Example:**

```hcl
# versions.tf

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}
```

### Provider Configuration File

Root modules **MUST** have a `providers.tf` file with provider configuration:

**AWS Example:**

```hcl
# providers.tf

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}
```

**Azure Example:**

```hcl
# providers.tf

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}
```

> **Note:** Azure does not support provider-level default tags, and Resource Group tags are not automatically inherited by resources. Define common tags in a `locals` block (for example, `local.common_tags`) and apply `tags = local.common_tags` consistently to each taggable resource; you can optionally enforce required tags via Azure Policy.

**GCP Example:**

```hcl
# providers.tf

provider "google" {
  project = var.project_id
  region  = var.region
}
```

> **Note:** GCP supports `default_labels` at the provider level (Google provider 4.x+), but label keys must be lowercase. For consistent lowercase enforcement or cross-provider compatibility, consider using a `locals` block for common labels.

### Backend Configuration

Root modules **MUST** configure a remote backend, either in `backend.tf` or within the `terraform` block:

**AWS Example:**

```hcl
# backend.tf - Example configuration

terraform {
  backend "s3" {
    bucket         = "acme-corp-terraform-state"  # Use your state bucket name
    key            = "environments/prod/terraform.tfstate"
    region         = "us-east-1"  # Use your preferred region
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

**Azure Example:**

```hcl
# backend.tf - Example configuration

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"  # Use your resource group
    storage_account_name = "stacmeterraform"  # Use your storage account
    container_name       = "tfstate"
    key                  = "environments/prod/terraform.tfstate"
  }
}
```

**GCP Example:**

```hcl
# backend.tf - Example configuration

terraform {
  backend "gcs" {
    bucket = "acme-corp-terraform-state"  # Use your state bucket name
    prefix = "environments/prod"
  }
}
```

> **Important:** Unlike resource blocks, backend blocks do not support variable interpolation. Example values in backend configuration (such as bucket names and regions) must be replaced with your organization's actual values before running `terraform init`. Alternatively, use [partial backend configuration](#partial-backend-configuration) to provide values at runtime.

#### Partial Backend Configuration

As an alternative to placeholder values, Terraform supports **partial backend configuration**. This pattern separates static configuration (committed to version control) from dynamic values (provided at runtime):

**AWS Backend file (committed):**

```hcl
# backend.tf - partial configuration

terraform {
  backend "s3" {
    key     = "environments/prod/terraform.tfstate"
    encrypt = true
    # bucket, region, and dynamodb_table provided via -backend-config
  }
}
```

**AWS Backend config file (environment-specific):**

```hcl
# config/prod.s3.tfbackend

bucket         = "acme-corp-terraform-state"
region         = "us-east-1"
dynamodb_table = "terraform-locks"
```

**Azure Backend file (committed):**

```hcl
# backend.tf - partial configuration

terraform {
  backend "azurerm" {
    key = "environments/prod/terraform.tfstate"
    # resource_group_name, storage_account_name, container_name provided via -backend-config
  }
}
```

**Azure Backend config file (environment-specific):**

```hcl
# config/prod.azurerm.tfbackend

resource_group_name  = "rg-terraform-state"
storage_account_name = "stacmeterraform"
container_name       = "tfstate"
```

**GCP Backend file (committed):**

```hcl
# backend.tf - partial configuration

terraform {
  backend "gcs" {
    prefix = "environments/prod"
    # bucket provided via -backend-config
  }
}
```

**GCP Backend config file (environment-specific):**

```hcl
# config/prod.gcs.tfbackend

bucket = "acme-corp-terraform-state"
```

**Usage:**

```bash
terraform init -backend-config=config/prod.s3.tfbackend      # AWS
terraform init -backend-config=config/prod.azurerm.tfbackend  # Azure
terraform init -backend-config=config/prod.gcs.tfbackend      # GCP
```

This pattern is useful when:

- Backend values vary by environment but the state key structure is consistent
- Teams prefer runtime configuration over placeholder replacement
- CI/CD pipelines inject backend configuration dynamically

Both the inline example values and partial configuration pattern are valid approaches. Choose the pattern that best fits your team's workflow.

### Variable Files (.tfvars)

Terraform variable files (`.tfvars`) provide environment-specific or deployment-specific values. This section defines conventions for organizing and managing these files.

#### Naming Conventions

| Pattern | Use Case | Example |
| --- | --- | --- |
| `terraform.tfvars` | Default values loaded automatically | `terraform.tfvars` |
| `<environment>.tfvars` | Environment-specific values | `prod.tfvars`, `dev.tfvars` |
| `<environment>.auto.tfvars` | Auto-loaded environment values | `prod.auto.tfvars` |

#### Content Guidelines

**What belongs in `.tfvars` files:**

- Environment-specific values (e.g., instance sizes, replica counts)
- Non-sensitive configuration overrides
- Deployment-specific settings

**What does NOT belong in `.tfvars` files:**

- Secrets, API keys, or passwords — see [Security Best Practices](#security-best-practices)
- Hardcoded credentials or tokens
- Any value that should not be committed to version control

**Relationship to variable defaults:**

Values in `.tfvars` files override `default` values in variable declarations. The loading order is:

1. `default` value in `variables.tf`
2. Environment variables (`TF_VAR_name`)
3. `terraform.tfvars` and `terraform.tfvars.json` (if present)
4. `*.auto.tfvars` and `*.auto.tfvars.json` files (in alphabetical order)
5. `-var-file` command-line arguments (in order specified)
6. `-var` command-line arguments (later flags override earlier ones)

#### Version Control Guidelines

- Non-sensitive `.tfvars` files **MAY** be committed to version control
- Sensitive `.tfvars` files **MUST NOT** be committed; use `.tfvars.example` templates instead
- Template files **SHOULD** use the `.tfvars.example` extension to indicate they require customization

**Example `.gitignore` patterns for sensitive tfvars:**

```gitignore
# Sensitive variable files (use *.tfvars.example as templates)
*.sensitive.tfvars
*-secrets.tfvars
```

#### Example File Structure

```text
environments/
├── prod/
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars        # Committed: non-sensitive defaults
│   ├── secrets.tfvars.example  # Committed: template for secrets
│   └── secrets.tfvars          # NOT committed: actual secrets
└── dev/
    ├── main.tf
    ├── variables.tf
    └── terraform.tfvars
```

### Terraform Cloud Variable Precedence

When using Terraform Cloud or Terraform Enterprise, variables can be set at multiple levels. The precedence order (highest to lowest) is:

1. `-var` and `-var-file` flags in CLI-driven runs
2. `*.auto.tfvars` files (in alphabetical order)
3. `terraform.tfvars` (if present)
4. Workspace-specific variables (set in Terraform Cloud UI/API)
5. Variable sets (shared across workspaces)
6. Environment variables (`TF_VAR_*`)
7. `default` values in variable declarations

**Note:** In Terraform Cloud, workspace variables and variable sets take precedence over environment variables (`TF_VAR_*`). This differs from local Terraform execution where environment variables have higher precedence.

Document which variable management approach your organization uses in the [Scope Exceptions](#scope-exceptions--deviations-from-standards) section to ensure consistency across team members.

### Module Directory Structure

Standard module directory structure:

```text
modules/
└── <module-name>/
    ├── main.tf           # Primary resources
    ├── variables.tf      # Input variables (REQUIRED)
    ├── outputs.tf        # Output values (REQUIRED)
    ├── versions.tf       # Version constraints (REQUIRED)
    ├── README.md         # Module documentation (REQUIRED)
    ├── locals.tf         # Local values (when needed)
    ├── data.tf           # Data sources (when needed)
    ├── examples/         # Usage examples (RECOMMENDED)
    │   └── basic/
    │       ├── main.tf
    │       ├── variables.tf
    │       └── outputs.tf
    └── tests/            # Test files (RECOMMENDED)
        └── basic.tftest.hcl
```

### Module Examples

Modules **SHOULD** include an `examples/` directory with working examples:

- Each example **MUST** be a complete, runnable configuration
- Examples **SHOULD** demonstrate common use cases
- Examples **SHOULD** include a `README.md` explaining the example

### Module Tests

Modules **SHOULD** include a `tests/` directory with Terraform test files:

- Tests **MUST** use the `.tftest.hcl` extension
- Tests **SHOULD** cover both valid and invalid inputs
- Tests **SHOULD** validate critical outputs

### Template Files (.tftpl)

Template files are used with the `templatefile()` function to generate dynamic content such as configuration files, scripts, or policy documents. Template files **SHOULD** follow these conventions:

- Template files **SHOULD** use the `.tftpl` extension for clear identification
- Template files **SHOULD** be placed in a `templates/` subdirectory within the module or root configuration
- Template file variables **SHOULD** be documented at the top of the template file using comments

**Directory structure:**

```text
modules/
└── <module-name>/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── templates/
        ├── user_data.sh.tftpl
        └── policy.json.tftpl
```

**Template file example with documentation:**

```tftpl
#!/bin/bash
# Template: user_data.sh.tftpl
# Variables:
#   - environment: Deployment environment (string)
#   - app_name: Application name (string)
#   - enable_monitoring: Whether to enable monitoring (bool)

echo "Deploying ${app_name} to ${environment}"

%{ if enable_monitoring ~}
echo "Monitoring enabled"
%{ endif ~}
```

**Using templatefile() function:**

```hcl
resource "aws_instance" "main" {
  ami           = var.ami_id
  instance_type = var.instance_type

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    environment       = var.environment
    app_name          = var.app_name
    enable_monitoring = var.enable_monitoring
  })
}
```

---

## Variable and Output Design

### Variable Documentation Requirements

Every variable **MUST** include a `description`. The description **SHOULD** explain:

- What the variable is for
- Valid values or constraints
- Any special considerations

```hcl
variable "environment" {
  description = "Deployment environment. Valid values: dev, staging, prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

### Variable Type Constraints

Variables **MUST** include explicit `type` constraints:

```hcl
# String variable
variable "instance_type" {
  description = "EC2 instance type for the application server."
  type        = string
  default     = "t3.micro"
}

# List variable
variable "subnet_ids" {
  description = "List of subnet IDs for deployment."
  type        = list(string)
}

# Map variable
variable "tags" {
  description = "Additional tags to apply to resources."
  type        = map(string)
  default     = {}
}

# Object variable
variable "instance_config" {
  description = "Configuration for the EC2 instance."
  type = object({
    instance_type = string
    ami_id        = string
    volume_size   = optional(number, 20)
  })
}
```

### Variable Defaults

Optional variables **MUST** have a `default` value. Required variables **MUST NOT** have a `default`.

```hcl
# Required variable (no default)
variable "vpc_id" {
  description = "VPC ID where resources will be created."
  type        = string
}

# Optional variable (has default)
variable "enable_monitoring" {
  description = "Enable CloudWatch detailed monitoring."
  type        = bool
  default     = false
}
```

### Variable Validation

Variables with constrained values **SHOULD** use `validation` blocks:

```hcl
variable "environment" {
  description = "Deployment environment. Valid values: dev, staging, prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "instance_count" {
  description = "Number of instances to create. Must be between 1 and 10."
  type        = number

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "cidr_block" {
  description = "CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid CIDR block."
  }
}
```

### Sensitive Variable Marking

Variables containing sensitive data **MUST** be marked:

```hcl
variable "database_password" {
  description = "Password for the RDS database. Must be provided via environment variable or tfvars."
  type        = string
  sensitive   = true
}

variable "api_key" {
  description = "API key for external service"
  type        = string
  sensitive   = true
}
```

### Output Documentation Requirements

Every output **MUST** include a `description`:

```hcl
output "instance_id" {
  description = "The ID of the created EC2 instance."
  value       = aws_instance.main.id
}

output "instance_public_ip" {
  description = "The public IP address of the EC2 instance."
  value       = aws_instance.main.public_ip
}
```

### Sensitive Output Marking

Outputs containing sensitive data **MUST** be marked:

```hcl
output "database_connection_string" {
  description = "Database connection string (contains credentials)."
  value       = local.connection_string
  sensitive   = true
}

output "instance_private_ip" {
  description = "The private IP address of the EC2 instance."
  value       = aws_instance.main.private_ip
  sensitive   = true
}
```

### Nullable Variables

The `nullable` attribute (Terraform 1.1+) controls whether a variable can accept `null` as a valid value. By default, all variables have `nullable = true`, meaning they can accept `null` values.

**Purpose:**

- Explicitly allow or disallow `null` as a valid value
- Distinguish between "not provided" and "explicitly set to null"
- Improve input validation for required values

**When to use explicit `nullable`:**

- Use `nullable = true` when `null` is a meaningful value distinct from the default
- Use `nullable = false` when `null` values **MUST** be rejected

**Example:**

```hcl
variable "optional_cidr" {
  description = "Optional secondary CIDR block. Set to null to skip configuration."
  type        = string
  default     = null
  nullable    = true  # Explicitly allow null values
}

variable "required_name" {
  description = "Required resource name. Cannot be null."
  type        = string
  nullable    = false  # Null values will be rejected
}
```

**Usage pattern:**

```hcl
resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  count = var.optional_cidr != null ? 1 : 0

  vpc_id     = aws_vpc.main.id
  cidr_block = var.optional_cidr
}
```

### Null Value Patterns

Terraform provides several functions and patterns for handling null values effectively. This section documents common patterns for working with potentially null values.

**Using `coalesce()` for fallback values:**

```hcl
locals {
  # Use provided value or fall back to default
  instance_type = coalesce(var.instance_type_override, "t3.micro")

  # Chain multiple fallbacks
  region = coalesce(var.region, data.aws_region.current.name, "us-east-1")
}
```

**Handling null in conditional expressions:**

```hcl
resource "aws_instance" "main" {
  ami           = var.ami_id
  instance_type = var.instance_type

  # Only set user_data if provided, otherwise use default script
  user_data = var.custom_user_data != null ? var.custom_user_data : file("${path.module}/default_user_data.sh")
}
```

**Null handling in `for` expressions:**

```hcl
locals {
  # Filter out null values from a list
  valid_subnets = [for s in var.subnet_ids : s if s != null]

  # Filter out entries with null values from a map
  valid_tags = { for k, v in var.tags : k => v if v != null }
}
```

**Using `optional()` with defaults (Terraform 1.3+):**

```hcl
variable "instance_config" {
  type = object({
    instance_type = string
    volume_size   = optional(number, 20)      # Defaults to 20 when attribute is not set
    monitoring    = optional(bool, false)     # Defaults to false when attribute is not set
  })
}
```

### Defensive Attribute Access with try()

The `try()` function attempts to evaluate expressions and returns a fallback value if any expression fails. Use it for defensive access to attributes that may not exist.

**Syntax:** `try(expression, fallback)`

**Use cases:**

```hcl
locals {
  # Safely access nested attributes that may not exist
  instance_ip = try(aws_instance.main.private_ip, "unknown")

  # Handle optional nested blocks
  root_volume_size = try(aws_instance.main.root_block_device[0].volume_size, 8)

  # Chain multiple attempts
  endpoint = try(
    aws_db_instance.main.endpoint,
    aws_rds_cluster.main.endpoint,
    "no-database-configured"
  )
}
```

**Difference between `try()` and `can()`:**

| Function | Returns | Use Case |
| --- | --- | --- |
| `try(expr, fallback)` | The value of `expr` if successful, otherwise `fallback` | Getting a value with a default |
| `can(expr)` | `true` if `expr` evaluates without error, `false` otherwise | Validation conditions |

```hcl
# Use can() in validation blocks
validation {
  condition     = can(regex("^[a-z][a-z0-9-]*$", var.name))
  error_message = "Name must start with a letter and contain only lowercase alphanumeric characters and hyphens."
}

# Use try() when you need the actual value
locals {
  parsed_json = try(jsondecode(var.config_json), {})
}
```

---

## Continuous Validation with check Blocks

The `check` block (Terraform 1.5+) provides a mechanism for continuous validation assertions that run on every `plan` and `apply` operation. Unlike `precondition` and `postcondition` blocks, `check` blocks produce **warning diagnostics** that do **not** halt execution when assertions fail.

### When to Use check Blocks

`check` blocks **MAY** be used for deterministic validations that rely only on Terraform configuration, state, and resource attributes, such as:

- **Policy conformance:** Ensure resources comply with tagging, encryption, and sizing standards
- **Configuration invariants:** Assert relationships between resources (for example, capacity, counts, or naming patterns)
- **Drift and safety nets:** Highlight situations where the actual infrastructure shape no longer matches declared expectations

In this repository, `check` block `assert` conditions **MUST** be deterministic and **MUST NOT** introduce network calls or depend on live external service reachability. Use dedicated observability/monitoring tooling for runtime health checks and external dependency validation.

### check Block Syntax

```hcl
check "alb_has_listeners" {
  assert {
    condition     = length(aws_lb_listener.app) > 0
    error_message = "Application load balancer must have at least one listener configured."
  }
}
```

### Comparison with precondition/postcondition

| Feature | `check` blocks | `precondition`/`postcondition` |
| --- | --- | --- |
| **Causes failure** | No (warning only) | Yes (error) |
| **Runs during** | Every plan/apply | Resource creation/update |
| **Scope** | Configuration-wide | Resource-specific |
| **Use case** | Ongoing invariant checks | Input/output validation |

### Best Practices

- **Bounded usage:** Each module **SHOULD** define at most 3 `check` blocks and **SHOULD** reserve them for critical invariants (for example, cross-resource consistency or security posture), not routine validation that can be handled with `precondition`/`postcondition`.
- **Deterministic and cheap assertions:** `condition` expressions **MUST** be deterministic (no dependence on current time, randomness, or external services) and **MUST NOT** introduce additional network calls (for example, avoid `http` or other remote data sources inside a `check` block). They **SHOULD** only reference values already available during planning (resource attributes, variables, locals, and data sources the plan already needs).
- **Constrained complexity:** Assertions **SHOULD** be expressed as a small number of boolean expressions combined with `&&`/`||`, and **SHOULD NOT** iterate over large collections or use deeply nested conditionals that materially increase plan/apply latency.
- **Document purpose:** `error_message` values **MUST** clearly state which invariant failed and what the operator **SHOULD** do next (for example, "rotate API token X" or "scale service Y").

---

## Resource Configuration

### Meta-Argument Ordering

Within resource blocks, arguments **MUST** follow this order:

1. **Meta-arguments first:** `count`, `for_each`, `provider`, `depends_on`, `lifecycle`
2. **Required arguments:** Arguments without defaults
3. **Optional arguments:** Arguments with defaults
4. **Nested blocks last:** Dynamic blocks, inline blocks

**Compliant example:**

```hcl
resource "aws_instance" "web_server" {
  # Meta-arguments first
  count    = var.instance_count
  provider = aws.primary

  # Required arguments
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  # Optional arguments
  associate_public_ip_address = var.is_public
  monitoring                  = var.enable_monitoring

  # Nested blocks last
  root_block_device {
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = local.common_tags

  # Lifecycle block at the end
  lifecycle {
    create_before_destroy = true
  }
}
```

### Argument Ordering

Within the arguments section:

1. Required arguments appear before optional arguments
2. Related arguments are grouped together
3. `tags` typically appears last before nested blocks

### Nested Block Placement

Nested blocks **MUST** appear after all simple arguments:

```hcl
resource "aws_security_group" "web" {
  # Simple arguments first
  name        = "${var.project_name}-web-sg"
  description = "Security group for web servers"
  vpc_id      = var.vpc_id

  # Nested blocks last
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}
```

### Required Tags

All taggable resources **MUST** include these tags:

| Tag | Description | Example |
| --- | --- | --- |
| `Name` | Human-readable resource name | `prod-web-server-1` |
| `Environment` | Deployment environment | `prod`, `staging`, `dev` |
| `Project` | Project or application name | `my-application` |
| `ManagedBy` | Management method | `terraform` |
| `Owner` | Team or individual owner | `platform-team` |

### Default Tags Configuration

Root modules **SHOULD** use provider-level default tags to ensure consistent tagging:

**AWS Example:**

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      Owner       = var.owner_team
    }
  }
}
```

> **Note:** Azure does not support provider-level default tags. GCP supports `default_labels` at the provider level (Google provider 4.x+), but label keys must be lowercase. For Azure, use a `locals` block to define common tags. For GCP, you may use `default_labels` or a `locals` block if you need consistent lowercase key enforcement. See the [Local Tags Pattern](#local-tags-pattern) section below.

### Local Tags Pattern

Use locals for computed or merged tags. This pattern is **REQUIRED** for Azure (no provider-level support) and **RECOMMENDED** for GCP when consistent lowercase label key enforcement is needed:

**AWS/Azure Example (Tags):**

```hcl
locals {
  common_tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }

  # Merge common tags with resource-specific tags
  instance_tags = merge(local.common_tags, {
    Role = "web-server"
  })
}
```

**GCP Example (Labels - lowercase keys required):**

```hcl
locals {
  # GCP labels must use lowercase keys
  common_labels = {
    name        = "${var.project_name}-${var.environment}"
    environment = var.environment
    project     = var.project_name
    managed_by  = "terraform"
  }

  # Merge common labels with resource-specific labels
  instance_labels = merge(local.common_labels, {
    role = "web-server"
  })
}
```

> **Note:** GCP label keys must be lowercase and can only contain lowercase letters, numeric characters, underscores, and dashes. AWS and Azure tags support mixed-case keys.

**Azure Example - Applying local tags to resources:**

```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}
```

**GCP Example - Applying local labels to resources:**

```hcl
resource "google_compute_instance" "main" {
  name         = "${var.project_name}-${var.environment}"
  machine_type = var.machine_type
  zone         = var.zone

  labels = local.common_labels
}
```

### Lifecycle Validation

Terraform 1.2+ introduced `precondition` and `postcondition` blocks within the `lifecycle` block, enabling resource-level validation of assumptions and outcomes.

#### Resource Preconditions

`precondition` blocks **SHOULD** validate assumptions before resource creation. Use them to ensure that related resources or variables meet requirements before Terraform attempts to create or modify a resource.

```hcl
resource "aws_instance" "main" {
  ami           = var.ami_id
  instance_type = var.instance_type

  lifecycle {
    precondition {
      condition     = var.environment != "prod" || var.enable_monitoring
      error_message = "Production instances must have monitoring enabled."
    }
  }
}
```

**Use cases for preconditions:**

- Validating cross-resource dependencies
- Enforcing business rules that span multiple variables
- Ensuring prerequisites are met before expensive operations

#### Resource Postconditions

`postcondition` blocks **SHOULD** validate resource state after creation. Use them to ensure that computed values meet expectations after Terraform creates or modifies a resource.

```hcl
resource "aws_instance" "main" {
  ami           = var.ami_id
  instance_type = var.instance_type

  lifecycle {
    postcondition {
      condition     = self.public_ip != null
      error_message = "Instance must have a public IP assigned."
    }
  }
}
```

**Use cases for postconditions:**

- Validating computed attributes (IPs, ARNs, generated names)
- Ensuring provider-side defaults meet expectations
- Catching unexpected resource configurations

### Lifecycle Block Options

The `lifecycle` block supports several meta-argument options beyond `precondition` and `postcondition` for controlling resource behavior. The following table summarizes these lifecycle meta-arguments:

| Option | Purpose | Use Case |
| --- | --- | --- |
| `create_before_destroy` | Create replacement before destroying original | Zero-downtime replacements |
| `prevent_destroy` | Prevent accidental resource deletion | Protect critical production resources |
| `ignore_changes` | Ignore changes to specific attributes | Attributes managed outside Terraform |
| `replace_triggered_by` | Force replacement when dependencies change | Trigger replacement on related resource changes (Terraform 1.2+) |

#### When to Use Each Option

**`create_before_destroy`:** Use when replacing a resource must not cause downtime. The new resource is created first, then the old one is destroyed.

**`prevent_destroy`:** Use for critical resources that **MUST NOT** be accidentally deleted, such as production databases, state storage buckets, or encryption keys.

**`ignore_changes`:** Use when an attribute is intentionally managed outside Terraform (e.g., auto-scaling group desired capacity, tags managed by external tools).

**`replace_triggered_by`:** Use when a resource **SHOULD** be replaced whenever a related resource changes, even if no direct attributes are affected.

#### Example: Protecting a Critical Resource

```hcl
# Protect production database from accidental deletion
resource "aws_db_instance" "production" {
  identifier     = "prod-database"
  engine         = "postgres"
  instance_class = var.db_instance_class
  # ... other configuration

  lifecycle {
    prevent_destroy = true
  }
}

# Protect Terraform state bucket
resource "aws_s3_bucket" "terraform_state" {
  bucket = "acme-corp-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}
```

#### Example: Ignoring External Changes

```hcl
# Ignore changes to tags managed by AWS Config or other external tools
resource "aws_instance" "main" {
  ami           = var.ami_id
  instance_type = var.instance_type

  lifecycle {
    ignore_changes = [
      tags["LastScannedBy"],
      tags["ComplianceStatus"],
    ]
  }
}
```

### Resource Timeouts

Some Terraform resources support custom timeout configurations for create, update, and delete operations via a `timeouts` block. Timeouts are provider-specific—not all resources support them, and available timeout options vary by resource type.

#### Timeout Block Structure

```hcl
resource "aws_db_instance" "main" {
  identifier     = "production-database"
  engine         = "postgres"
  instance_class = var.db_instance_class
  # ... other configuration

  timeouts {
    create = "60m"
    update = "90m"
    delete = "30m"
  }
}
```

#### Common Use Cases

Custom timeouts are commonly needed for:

- **RDS/database instances:** Database creation and modification can take 30-60+ minutes
- **Large EKS/AKS/GKE clusters:** Kubernetes cluster operations may exceed default timeouts
- **Complex networking resources:** VPN gateways, Transit Gateway attachments, and peering connections
- **Large-scale storage operations:** Creating or resizing large storage volumes

> **Note:** Default timeouts are usually sufficient for most operations. Custom timeouts **SHOULD** only be set when operations consistently exceed default values or when specific SLAs require longer wait times.

### Explicit Dependencies

Terraform automatically infers dependencies from resource references. The `depends_on` meta-argument **SHOULD** be avoided unless dependencies are not inferable from the configuration.

#### When depends_on is Appropriate

`depends_on` **SHOULD** only be used for:

- **Hidden dependencies:** When a resource depends on another resource's side effects (e.g., IAM policy propagation delays)
- **Module dependencies:** When a module depends on another module's resources without direct references
- **Timing issues:** When the order of operations matters but isn't reflected in resource attributes

#### Anti-pattern: Redundant depends_on

```hcl
# BAD: Unnecessary depends_on - dependency is already inferred from the reference
resource "aws_instance" "main" {
  subnet_id  = aws_subnet.main.id
  depends_on = [aws_subnet.main]  # Redundant
}

# GOOD: Dependency is implicit from the reference
resource "aws_instance" "main" {
  subnet_id = aws_subnet.main.id
}
```

#### Legitimate Use Case

```hcl
# GOOD: Hidden dependency on IAM role policy attachment
resource "aws_instance" "main" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile = aws_iam_instance_profile.main.name

  # The instance profile references the role, but doesn't reference the policy attachment.
  # Without depends_on, the instance may launch before the policy is attached.
  depends_on = [aws_iam_role_policy_attachment.main]
}
```

### Module-Level depends_on

The `depends_on` meta-argument can also be used at the module level (Terraform 0.13+). However, module-level `depends_on` has different implications than resource-level `depends_on` and **SHOULD** be used sparingly.

**Key differences from resource-level depends_on:**

- When a module block uses `depends_on` with a **module address** (for example, `depends_on = [module.networking]`), it creates a dependency on **all resources in that referenced module**
- When a module block uses `depends_on` with a **resource address**, it creates a dependency only on that specific resource (not all resources in its module)
- This can cause unnecessary serialization and slower apply times when used with module addresses
- It is a blunt instrument that should only be used when finer-grained dependencies cannot be expressed

**When module-level depends_on is appropriate:**

- When a module depends on side effects from another module (e.g., IAM propagation, DNS resolution delays)
- When there is no data to pass between modules but ordering is required
- When debugging timing issues during development (should be removed after identifying root cause)

**Example: Legitimate use case:**

```hcl
# Module-level depends_on - use sparingly
module "application" {
  source = "./modules/application"

  vpc_id = module.networking.vpc_id

  # Only use when implicit dependencies are insufficient
  # (e.g., module.networking creates IAM roles needed by the application)
  depends_on = [module.networking]
}
```

**Anti-pattern: Redundant module depends_on:**

```hcl
# AVOID: Unnecessary module depends_on when data is already passed
module "application" {
  source = "./modules/application"

  vpc_id     = module.networking.vpc_id      # This creates implicit dependency
  subnet_ids = module.networking.subnet_ids  # This too

  depends_on = [module.networking]  # REDUNDANT - remove this
}
```

**Best practice:** Prefer explicit data passing between modules over `depends_on`. When you pass outputs from one module as inputs to another, Terraform automatically understands the dependency relationship.

### for_each vs count

When creating multiple instances of a resource, `for_each` **SHOULD** be preferred over `count` for collections where resources have unique identifiers.

#### Comparison Table

| Use `for_each` when... | Use `count` when... |
| --- | --- |
| Resources have unique identifiers | Simple on/off toggle (`count = var.enabled ? 1 : 0`) |
| Order doesn't matter | Resources are truly identical and ordered |
| Items may be added/removed from middle of collection | Only adding/removing from the end |
| Each resource is addressable by key | Index-based addressing is acceptable |

#### Why for_each is Preferred

Removing an item from a `count`-based list causes all subsequent resources to be recreated due to index shifting. `for_each` uses map keys, so only the specific resource is affected.

```hcl
# BAD: Using count with a list - removing any item shifts all subsequent indices
resource "aws_instance" "servers" {
  count         = length(var.server_names)
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  tags = {
    Name = var.server_names[count.index]
  }
}

# GOOD: Using for_each with a set - removing "server-b" only affects that resource
resource "aws_instance" "servers" {
  for_each      = toset(var.server_names)
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  tags = {
    Name = each.value
  }
}
```

#### When count is Appropriate

```hcl
# GOOD: count for conditional resource creation
resource "aws_cloudwatch_log_group" "main" {
  count = var.enable_logging ? 1 : 0
  name  = "/app/${var.environment}"
}
```

#### Conditional Resource Creation

The `count` meta-argument is appropriate for conditional resource creation using a boolean toggle:

```hcl
variable "enable_logging" {
  description = "Whether to create the CloudWatch log group"
  type        = bool
  default     = false
}

resource "aws_cloudwatch_log_group" "main" {
  count = var.enable_logging ? 1 : 0
  name  = "/app/${var.environment}"
}
```

**Referencing conditional resources:**

When referencing a conditionally created resource, use index `[0]` and handle the case where it doesn't exist:

```hcl
# Safe reference to conditional resource
output "log_group_arn" {
  description = "ARN of the log group, if created"
  value       = var.enable_logging ? aws_cloudwatch_log_group.main[0].arn : null
}

# Alternative using try() for readability
# try() returns the first argument when the resource exists, or null when it does not
output "log_group_name" {
  description = "Name of the log group, if created"
  value       = try(aws_cloudwatch_log_group.main[0].name, null)
}
```

### Dynamic Blocks

Dynamic blocks allow generating multiple nested blocks from a collection. They **SHOULD** be used sparingly because they reduce readability and complicate debugging.

#### When to Use Dynamic Blocks

Use dynamic blocks when:

- The number of nested blocks is variable and determined by configuration
- The block structure is repetitive and follows a consistent pattern
- Manual repetition would create maintenance burden

```hcl
# GOOD: Variable number of ingress rules from configuration
resource "aws_security_group" "main" {
  name        = "${var.project_name}-sg"
  description = "Security group for ${var.project_name}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

#### When to Avoid Dynamic Blocks

Avoid dynamic blocks when the number of blocks is fixed and small. Writing explicit blocks improves readability:

```hcl
# GOOD: Fixed, small number of rules - explicit is clearer
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Web security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# AVOID: Using dynamic for only 2-3 fixed rules adds unnecessary complexity
# dynamic "ingress" { ... }
```

### The terraform_data Resource

The `terraform_data` resource (Terraform 1.4+) is a built-in managed resource that provides trigger-based replacement and data passing without requiring any provider. It is the **preferred replacement** for `null_resource` in modern Terraform configurations.

#### When to Use terraform_data

- **Trigger-based replacement:** Force resource replacement when specific values change
- **Data passing:** Store and pass values between resources or modules
- **Provisioner execution:** Run local-exec or remote-exec provisioners (same as null_resource)

**Advantages over null_resource:**

- No provider dependency (built into Terraform core)
- Clearer semantics with `input` and `output` attributes
- Better integration with the dependency graph

#### Basic Usage Pattern

```hcl
resource "terraform_data" "replacement" {
  input = var.revision

  # Force replacement when any of these values change
  triggers_replace = [
    aws_instance.main.id,
    var.force_replacement,
  ]
}

# Reference the trigger in other resources
resource "aws_instance" "dependent" {
  # ...

  lifecycle {
    replace_triggered_by = [terraform_data.replacement]
  }
}
```

#### Using input and output Attributes

The `input` attribute accepts any value and makes it available as `output`:

```hcl
resource "terraform_data" "config" {
  input = {
    environment = var.environment
    version     = var.app_version
    timestamp   = timestamp()
  }
}

# Access the stored values
output "deployment_config" {
  description = "Configuration used for this deployment."
  value       = terraform_data.config.output
}
```

#### Migration from null_resource

When migrating from `null_resource` to `terraform_data`:

```hcl
# Before (null_resource)
resource "null_resource" "trigger" {
  triggers = {
    instance_id = aws_instance.main.id
  }
}

# After (terraform_data) - preferred
resource "terraform_data" "trigger" {
  triggers_replace = [aws_instance.main.id]
}
```

> **Note:** `terraform_data` requires Terraform 1.4.0 or later. For configurations that must support older versions, `null_resource` remains available via the `hashicorp/null` provider.

---

## Module Design

### Single Responsibility

Modules **MUST** have a single, well-defined responsibility:

- Each module **SHOULD** manage one logical component
- Modules **SHOULD NOT** try to do too much
- Complex infrastructure **SHOULD** be composed of multiple modules

**Good:** A VPC module that creates VPC, subnets, route tables, and internet gateway.

**Bad:** A "full-stack" module that creates VPC, EC2, RDS, and S3 all together.

### Module Version Constraints

Modules **MUST** specify required Terraform and provider versions:

```hcl
# versions.tf in module directory

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}
```

### Module Interface Design

**Inputs:**

- Variable names **MUST** be consistent across modules (e.g., always `environment`, not sometimes `env`)
- Required variables **SHOULD** be minimized to essential values
- Complex inputs **SHOULD** use object types with documented structure

**Outputs:**

- Expose only values needed by calling modules
- Use consistent naming patterns across modules
- Document output types and formats

### Minimal Required Inputs

Required variables **SHOULD** be minimized. Provide sensible defaults where possible:

```hcl
# Good: Only truly required inputs are mandatory
variable "vpc_id" {
  description = "VPC ID where resources will be created."
  type        = string
  # No default - this is genuinely required
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"  # Sensible default
}
```

### Complex Input Types

For complex inputs, use object types with clear documentation:

```hcl
variable "instance_config" {
  description = <<-EOT
    Configuration for the EC2 instance.

    Attributes:
      - instance_type: EC2 instance type (e.g., "t3.micro")
      - ami_id: AMI ID to use for the instance
      - volume_size: Root volume size in GB (default: 20)
      - enable_monitoring: Enable detailed monitoring (default: false)
  EOT
  type = object({
    instance_type     = string
    ami_id            = string
    volume_size       = optional(number, 20)
    enable_monitoring = optional(bool, false)
  })
}
```

### Module Output Design

Outputs **SHOULD** expose only values needed by calling modules:

```hcl
# Good: Specific, useful outputs
output "instance_id" {
  description = "The ID of the created EC2 instance."
  value       = aws_instance.main.id
}

output "instance_private_ip" {
  description = "The private IP address of the EC2 instance."
  value       = aws_instance.main.private_ip
}

# Avoid: Exposing entire resource
output "instance" {
  description = "The entire instance resource."
  value       = aws_instance.main  # Too broad
}
```

### Module Versioning

For published modules, use semantic versioning:

- **MAJOR:** Breaking changes (removed inputs, changed behavior)
- **MINOR:** New features, backward-compatible changes
- **PATCH:** Bug fixes, documentation updates

Pin module versions in root configurations:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  # ...
}

module "internal_module" {
  source = "./modules/my-module"
  # Local modules don't use version constraint
}
```

---

## Refactoring

Terraform provides declarative blocks for safely refactoring infrastructure without manual state manipulation. These blocks enable auditable, version-controlled changes that can be reviewed and tested before applying.

### Refactoring with Moved Blocks

The `moved` block (Terraform 1.1+) enables renaming or restructuring resources without destroying and recreating them. This is essential for:

- Renaming resources to follow updated naming conventions
- Restructuring modules
- Moving resources between modules

**Syntax and Example:**

```hcl
moved {
  from = aws_instance.web
  to   = aws_instance.web_server
}

resource "aws_instance" "web_server" {
  # Previously aws_instance.web
  ami           = var.ami_id
  instance_type = var.instance_type
  # ...
}
```

**Requirements:**

- You **MUST** run `terraform plan` before applying the `moved` block changes and again after applying/refactoring to verify that no unexpected changes remain
- The `moved` block **SHOULD** remain in configuration until all environments have been updated
- After all state has been migrated, `moved` blocks **MAY** be removed

### Importing Resources with Import Blocks

The `import` block (Terraform 1.5+) brings existing infrastructure under Terraform management. This is preferred over the `terraform import` CLI command because:

- Import configuration is version-controlled and reviewable
- Multiple imports can be planned and applied together
- Import intentions are visible in code review

**Syntax and Example:**

```hcl
import {
  to = aws_instance.example
  id = "i-0abc123def456789"
}

resource "aws_instance" "example" {
  # Configuration matching the imported resource
  ami           = "ami-0abcdef1234567890"
  instance_type = "t3.micro"
  # ...
}
```

**Requirements:**

- The resource configuration **MUST** match the existing infrastructure
- You **MUST** run `terraform plan` before applying imports to verify the import will not cause unintended changes
- After successful import and apply, you **SHOULD** run `terraform plan` again to verify no further changes are pending, and `import` blocks **SHOULD** then be removed from configuration

### Removing Resources from State with Removed Blocks

The `removed` block (Terraform 1.7+) removes resources from Terraform management without destroying the underlying infrastructure. Use cases include:

- Transitioning resource ownership to another team or configuration
- Removing resources that are now managed outside Terraform
- Cleaning up state without affecting production infrastructure

**Syntax and Example:**

```hcl
removed {
  from = aws_instance.legacy

  lifecycle {
    destroy = false  # Remove from state without destroying
  }
}
```

**The `lifecycle.destroy` Option:**

| Value | Behavior |
| --- | --- |
| `true` (default) | Resource is destroyed when removed from configuration |
| `false` | Resource is removed from state but preserved in the cloud |

**Requirements:**

- Use `destroy = false` when the resource **MUST** continue to exist
- The reason for removal **MUST** be documented in comments or commit messages
- After successful apply, `removed` blocks **MAY** be removed from configuration

### State Manipulation Commands

Direct state manipulation commands (`terraform state mv`, `terraform state rm`, `terraform import`) **SHOULD** be avoided in favor of the declarative blocks above. The declarative approach provides:

- Version control and audit trail
- Code review before changes
- Consistent behavior across team members
- Reduced risk of human error

**When state commands are necessary, they MUST be:**

- Documented in commit messages with clear rationale
- Performed only after creating state backups
- Reviewed by a second team member when possible
- Followed by verification that state is consistent

**Backup command before state manipulation:**

```bash
terraform state pull > terraform.tfstate.backup
```

---

## State Management

> **Note:** For state modification best practices including resource renaming, importing existing infrastructure, and removing resources from management, see the [Refactoring](#refactoring) section.

### Remote Backend Configuration

Root modules **MUST** configure a remote backend for team environments:

**AWS Example:**

```hcl
terraform {
  backend "s3" {
    bucket         = "acme-corp-terraform-state"
    key            = "environments/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

**Azure Example:**

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stacmeterraform"
    container_name       = "tfstate"
    key                  = "environments/prod/terraform.tfstate"
  }
}
```

**GCP Example:**

```hcl
terraform {
  backend "gcs" {
    bucket = "acme-corp-terraform-state"
    prefix = "environments/prod"
  }
}
```

> **Example Values:** The examples above use illustrative values (e.g., `acme-corp-terraform-state`). Replace these with your organization's actual values when adopting this template.

**Backend requirements:**

- State files **MUST** be encrypted at rest
- State access **MUST** be controlled via appropriate access controls (e.g., IAM for AWS, RBAC for Azure, IAM for GCP)
- State locking **MUST** be enabled to prevent concurrent modifications
- State files **MUST NOT** be committed to version control

### Terraform Cloud, Enterprise, and Alternative Backends

Organizations using **Terraform Cloud**, **Terraform Enterprise**, **Spacelift**, or similar workflow tools **MAY** use alternative state management approaches. In these cases:

- The `backend.tf` file **MAY** be omitted if state is managed by the orchestration platform.
- The `cloud` block **MAY** replace the `backend` block for Terraform Cloud/Enterprise integrations.
- Document your backend approach in the [Scope Exceptions](#scope-exceptions--deviations-from-standards) section.

**Example Terraform Cloud configuration:**

```hcl
terraform {
  cloud {
    organization = "acme-corp"
    workspaces {
      name = "prod-infrastructure"
    }
  }
}
```

When using alternative backends, the following sections still apply:

- State encryption requirements (handled by the platform)
- State locking requirements (typically automatic with cloud backends)
- Version control exclusion of state files

The following sections **MAY** not apply when using Terraform Cloud/Enterprise:

- Manual `backend.tf` configuration
- DynamoDB lock table configuration
- S3/GCS/Azure Storage bucket configuration

### Terraform Cloud Workspace Configuration

Terraform Cloud supports two patterns for workspace selection: explicit naming and tag-based selection.

**Explicit workspace selection:**

The `name` attribute selects a specific, named workspace:

```hcl
terraform {
  cloud {
    organization = "acme-corp"
    workspaces {
      name = "prod-infrastructure"
    }
  }
}
```

**Tag-based workspace selection:**

The `tags` attribute enables dynamic workspace selection based on workspace tags. Terraform will operate on all workspaces that have **all** of the specified tags:

```hcl
terraform {
  cloud {
    organization = "acme-corp"
    workspaces {
      tags = ["app:my-application", "env:production"]
    }
  }
}
```

**Key differences:**

| Attribute | Behavior | Use Case |
| --- | --- | --- |
| `name` | Selects a single, specific workspace | Standard deployments with known workspace names |
| `tags` | Selects all workspaces matching the specified tags | Multi-workspace operations, batch deployments |

**Common patterns with tags:**

- Use `tags` for operations that should apply to multiple environments (e.g., deploying a fix to all production workspaces)
- Combine application and environment tags for precise targeting
- Tags are defined in Terraform Cloud, not in the configuration

> **Note:** You cannot use both `name` and `tags` in the same `workspaces` block. Choose one pattern based on your workflow requirements.

### Bootstrapping State Infrastructure

When creating a new Terraform configuration, you face a chicken-and-egg problem: the remote backend (e.g., S3 bucket, Azure Storage Account, GCS bucket) must exist before Terraform can use it to store state, but you want Terraform to manage that backend infrastructure.

#### Bootstrap Workflow

**Step 1: Create bootstrap configuration with backend commented out:**

Create your state storage resources in a dedicated bootstrap configuration, initially without a backend block (or with the backend block commented out). This allows Terraform to use local state temporarily.

**AWS Example (`bootstrap/versions.tf`):**

```hcl
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Backend will be added after bootstrap
  # backend "s3" {
  #   bucket         = "acme-corp-terraform-state"
  #   key            = "bootstrap/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

# Create the S3 bucket for state storage
# Note: S3 bucket names must be globally unique. See "Globally Unique Resource Names"
# section for patterns using random_id or organization prefixes.
resource "aws_s3_bucket" "terraform_state" {
  bucket = "acme-corp-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

**Azure Example (`bootstrap/main.tf`):**

```hcl
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Backend will be added after bootstrap
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "stacmeterraform"
  #   container_name       = "tfstate"
  #   key                  = "bootstrap/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "terraform_state" {
  name     = "rg-terraform-state"
  location = "eastus"
}

resource "azurerm_storage_account" "terraform_state" {
  name                     = "stacmeterraform"
  resource_group_name      = azurerm_resource_group.terraform_state.name
  location                 = azurerm_resource_group.terraform_state.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "terraform_state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.terraform_state.name
  container_access_type = "private"
}
```

**GCP Example (`bootstrap/main.tf`):**

```hcl
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  # Backend will be added after bootstrap
  # backend "gcs" {
  #   bucket = "acme-corp-terraform-state"
  #   prefix = "bootstrap"
  # }
}

resource "google_storage_bucket" "terraform_state" {
  name     = "acme-corp-terraform-state"
  location = "US"

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true
}
```

**Step 2: Apply locally to create state storage:**

```bash
cd bootstrap
terraform init
terraform apply
```

This creates the state storage infrastructure using local state (stored in `terraform.tfstate`).

**Step 3: Configure backend and migrate state:**

Uncomment or add the backend block in your configuration, then run:

```bash
terraform init -migrate-state
```

Terraform will prompt you to confirm migration of the existing local state to the remote backend.

**Step 4: Clean up local state file:**

After successful migration, the local state file is no longer needed:

```bash
rm terraform.tfstate terraform.tfstate.backup
```

> **Warning:** Only delete local state files after confirming the remote state is properly configured and accessible. Run `terraform plan` to verify that Terraform can read from the remote backend before deleting local files.

#### Alternative: Partial Backend Configuration

As documented in [Backend Configuration](#backend-configuration), you can use partial backend configuration to separate the bootstrap workflow from the backend values. This approach allows you to:

1. Commit a partial backend configuration without sensitive values
2. Provide backend values via `-backend-config` during `terraform init`
3. Manage state storage creation in a separate, pre-provisioned step

#### Bootstrap Best Practices

- **Separate bootstrap configuration:** Keep state infrastructure in a dedicated directory (`bootstrap/` or `infrastructure/state/`) separate from application infrastructure.
- **Use `prevent_destroy`:** Protect state storage resources from accidental deletion.
- **Enable versioning:** Always enable versioning on state storage buckets to allow recovery from corruption.
- **Document the process:** Include bootstrap instructions in your repository's README or contributing guide.

### State Encryption

State backends **MUST** enable encryption:

**AWS Example:**

```hcl
# S3 backend with encryption
terraform {
  backend "s3" {
    bucket  = "acme-corp-terraform-state"
    key     = "prod/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true  # REQUIRED
  }
}
```

**Azure Example:**

```hcl
# Azure Storage backend (encryption is enabled by default on Azure Storage accounts)
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stacmeterraform"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}
```

> **Note:** Azure Storage accounts have encryption enabled by default. Ensure your storage account is configured with appropriate encryption settings.

**GCP Example:**

```hcl
# GCS backend (encryption is enabled by default on GCS buckets)
terraform {
  backend "gcs" {
    bucket = "acme-corp-terraform-state"
    prefix = "prod"
  }
}
```

> **Note:** GCS buckets are encrypted by default using Google-managed encryption keys. For additional security, configure Customer-Managed Encryption Keys (CMEK).

### State Locking

State backends **MUST** support and enable state locking:

**AWS Example:**

```hcl
# S3 backend with DynamoDB locking
terraform {
  backend "s3" {
    bucket         = "acme-corp-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"  # REQUIRED for locking
  }
}
```

**Azure Example:**

```hcl
# Azure Storage backend (locking is built-in via blob leases)
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stacmeterraform"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}
```

> **Note:** Azure Storage backend uses blob leases for state locking automatically. No additional configuration is required.

**GCP Example:**

```hcl
# GCS backend (locking is built-in)
terraform {
  backend "gcs" {
    bucket = "acme-corp-terraform-state"
    prefix = "prod"
  }
}
```

> **Note:** GCS backend supports state locking natively. No additional configuration is required.

### No Local State in Production

Local state files **MUST NOT** be used for production environments. Local state:

- Cannot be shared across team members
- Has no locking mechanism
- Has no encryption at rest
- Is easily lost or corrupted

### State File Exclusion

State files and related artifacts **MUST NOT** be committed to version control. Add to `.gitignore`:

```gitignore
# Terraform state files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# .terraform directories
**/.terraform/*

# Override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# CLI configuration
.terraformrc
terraform.rc
```

### State File Organization

Organize state files by environment and component:

```text
state-bucket/
├── environments/
│   ├── dev/
│   │   └── terraform.tfstate
│   ├── staging/
│   │   └── terraform.tfstate
│   └── prod/
│       └── terraform.tfstate
└── shared/
    ├── networking/
    │   └── terraform.tfstate
    └── iam/
        └── terraform.tfstate
```

> **Note:** This diagram represents the **key/path structure in your remote backend** (S3 object keys, Azure blob paths, GCS object prefixes), not a local filesystem directory structure. These paths are configured via the `key` or `prefix` attribute in your backend configuration. Your local repository structure is separate and typically organized by environment directories containing Terraform configuration files.

### State Backup and Recovery

State files are critical infrastructure artifacts. Losing or corrupting state can result in significant operational challenges. This section documents backup strategies, manual backup procedures, and recovery approaches for common state-related problems.

#### State Versioning Requirements

State storage backends **MUST** have versioning enabled for production use:

- Versioning enables recovery from accidental state corruption or deletion
- Version retention period **SHOULD** be defined based on organizational requirements (typically 30-90 days minimum)
- Versioned state serves as a backup mechanism without additional tooling

#### State Backup Strategies

Each cloud provider offers native mechanisms for state versioning and backup.

**AWS S3 Backend:**

Enable versioning on the S3 bucket used for state storage:

```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "acme-corp-terraform-state"

  # Protect critical state storage from accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Optional: Configure lifecycle policy for version retention
# Uses time-based retention (90 days). Adjust based on your recovery requirements.
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "retain-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
```

To recover a previous state version from S3:

```bash
# List available versions
aws s3api list-object-versions \
  --bucket acme-corp-terraform-state \
  --prefix environments/prod/terraform.tfstate

# Download a specific version
aws s3api get-object \
  --bucket acme-corp-terraform-state \
  --key environments/prod/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.recovered
```

**Azure Storage Backend:**

Enable blob versioning or soft delete on the storage account:

```hcl
resource "azurerm_storage_account" "terraform_state" {
  name                     = "stacmeterraform"
  resource_group_name      = azurerm_resource_group.terraform_state.name
  location                 = azurerm_resource_group.terraform_state.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 90
    }

    container_delete_retention_policy {
      days = 90
    }
  }
}
```

To recover a previous state version from Azure Storage:

```bash
# List blob versions
az storage blob list \
  --account-name stacmeterraform \
  --container-name tfstate \
  --include v \
  --prefix environments/prod/terraform.tfstate \
  --output table

# Download a specific version
az storage blob download \
  --account-name stacmeterraform \
  --container-name tfstate \
  --name environments/prod/terraform.tfstate \
  --version-id <VERSION_ID> \
  --file terraform.tfstate.recovered
```

**GCS Backend:**

Enable object versioning on the GCS bucket:

```hcl
resource "google_storage_bucket" "terraform_state" {
  name     = "acme-corp-terraform-state"
  location = "US"

  versioning {
    enabled = true
  }

  # Optional: Configure lifecycle policy for version retention
  # GCS uses count-based retention (num_newer_versions) while AWS uses
  # time-based retention (noncurrent_days). Choose based on your needs:
  # - Count-based: Keeps last N versions regardless of age
  # - Time-based: Keeps versions for N days regardless of count
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
  }

  uniform_bucket_level_access = true
}
```

To recover a previous state version from GCS:

```bash
# List object versions
gsutil ls -la gs://acme-corp-terraform-state/environments/prod/

# Copy a specific generation (version)
gsutil cp gs://acme-corp-terraform-state/environments/prod/terraform.tfstate#<GENERATION> \
  terraform.tfstate.recovered
```

**Terraform Cloud:**

State versioning is automatic in Terraform Cloud. To access state history:

1. Navigate to your workspace in the Terraform Cloud UI
2. Click on "States" in the left navigation
3. Browse the list of state versions with timestamps
4. Click on any version to view details or download

State versions can also be accessed via the Terraform Cloud API:

```bash
# List state versions for a workspace
curl \
  --header "Authorization: Bearer $TFC_TOKEN" \
  https://app.terraform.io/api/v2/workspaces/<WORKSPACE_ID>/state-versions
```

#### Manual State Backup

Before performing risky operations, create a manual state backup:

```bash
# Create timestamped backup (Unix/Linux/macOS)
terraform state pull > terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)

# Windows PowerShell equivalent
# terraform state pull > "terraform.tfstate.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
```

**When manual backups are recommended:**

- Before running `terraform state rm` to remove resources from state
- Before running `terraform state mv` to move or rename resources
- Before major refactoring with `moved` blocks
- Before upgrading Terraform to a new major version
- Before running `terraform force-unlock`
- Before any operation that modifies state outside normal `apply` workflows

**To restore from a manual backup:**

```bash
# Review the backup contents first (local state file)
terraform show -json terraform.tfstate.backup.20260202_120000 | head -50

# Push the backup to the remote backend (use with caution)
terraform state push terraform.tfstate.backup.20260202_120000
```

> **Warning:** `terraform state push` overwrites the remote state. Ensure no other operations are in progress and that you have verified the backup contents before pushing.

#### Common State Problems and Recovery

##### Error: "Error acquiring the state lock"

**Symptoms:**

```text
Error: Error acquiring the state lock

Error message: ConditionalCheckFailedException: The conditional request failed
Lock Info:
  ID:        a1b2c3d4-e5f6-7890-abcd-ef1234567890
  Path:      terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@hostname
  Version:   1.7.0
  Created:   2026-02-01 10:30:00.000000000 +0000 UTC
```

**Cause:**

- A previous Terraform operation was interrupted (crash, network failure, timeout)
- Another user or CI job is currently running Terraform against the same state
- The lock was not properly released after a failed operation

**Solution:**

1. **First, verify no operations are in progress.** Check with your team and CI system.

2. **If confirmed safe, force-unlock the state:**

   ```bash
   terraform force-unlock a1b2c3d4-e5f6-7890-abcd-ef1234567890
   ```

3. **If the lock ID is unknown, check your backend directly:**
   - For DynamoDB (AWS): Check the lock table for the lock entry
   - For Azure: Check blob lease status
   - For GCS: Lock is file-based; typically auto-expires

**Prevention:**

- Ensure only one operator or CI job runs Terraform at a time
- Use CI/CD pipelines with proper concurrency controls
- Configure appropriate timeouts for long-running operations

> **Warning:** Never force-unlock a state if another operation is genuinely in progress. This can cause state corruption.

##### Error: "State file corrupted or invalid JSON"

**Symptoms:**

```text
Error: Failed to load state: unexpected end of JSON input
```

or

```text
Error: Failed to load state: invalid character '<' looking for beginning of value
```

**Cause:**

- Write operation was interrupted (network failure, process termination)
- Manual editing of state file with syntax errors
- Storage backend returned an error page instead of state file

**Solution:**

1. **Restore from backend versioning:**

   ```bash
   # Example for S3 - list versions and recover previous
   aws s3api list-object-versions \
     --bucket your-state-bucket \
     --prefix path/to/terraform.tfstate
   ```

2. **Restore from manual backup (if available):**

   ```bash
   terraform state push terraform.tfstate.backup.YYYYMMDD_HHMMSS
   ```

3. **If no backup exists, reconstruct from infrastructure:**

   ```bash
   # Remove corrupted state (create backup first)
   mv terraform.tfstate terraform.tfstate.corrupted

   # Re-import all resources using import blocks
   # See "Importing Resources with Import Blocks" section
   ```

**Prevention:**

- State files **MUST NOT** be manually edited
- Enable versioning on state storage (see [State Versioning Requirements](#state-versioning-requirements))
- Use reliable network connections for Terraform operations

##### Error: "Resource exists in state but not in cloud"

**Symptoms:**

```text
Error: Error reading resource: ResourceNotFoundException
```

Terraform shows a resource in state, but the actual cloud resource has been deleted outside of Terraform (manually, via console, or by another tool).

**Cause:**

- Resource was deleted outside Terraform (console, CLI, another tool)
- Resource was deleted by cloud provider (expiration, policy enforcement)
- Incorrect AWS account, Azure subscription, or GCP project configured

**Solution:**

**Option 1: Remove from state using `removed` block (preferred):**

```hcl
removed {
  from = aws_instance.deleted_instance

  lifecycle {
    destroy = false
  }
}
```

**Option 2: Remove from state using CLI:**

```bash
# Create backup first
terraform state pull > terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)

# Remove the resource from state
terraform state rm aws_instance.deleted_instance
```

**Prevention:**

- Establish processes to ensure infrastructure changes go through Terraform
- Use `prevent_destroy` lifecycle rule for critical resources
- Implement drift detection (scheduled `terraform plan` in CI)

##### Error: "Resource exists in cloud but not in state"

**Symptoms:**

Terraform plans to create a resource, but the resource already exists in the cloud. Or, you have infrastructure created outside Terraform that you want to bring under management.

**Cause:**

- Resource was created outside Terraform (manually, via console, or by another tool)
- State was lost or corrupted
- Resource was removed from state but not destroyed

**Solution:**

**Option 1: Use `import` block (preferred, Terraform 1.5+):**

```hcl
import {
  to = aws_instance.existing
  id = "i-0abc123def456789"
}

resource "aws_instance" "existing" {
  ami           = "ami-0abcdef1234567890"
  instance_type = "t3.micro"
  # ... configuration matching existing resource
}
```

Then run:

```bash
terraform plan  # Verify import will succeed
terraform apply # Perform the import
```

**Option 2: Use CLI import (legacy):**

```bash
terraform import aws_instance.existing i-0abc123def456789
```

After importing, review the state and update your configuration to match the imported resource's attributes.

**Prevention:**

- Establish processes to ensure infrastructure creation goes through Terraform
- Use workspace-specific naming conventions to identify Terraform-managed resources
- Tag resources with `ManagedBy = "terraform"` to identify ownership

### Workspace Usage

Workspaces **MAY** be used for environment separation in simple cases:

```bash
terraform workspace select prod
terraform apply
```

**Caution:** For complex environments, separate state files per environment are often clearer than workspaces.

### Environment Separation Strategies

Organizations need a consistent strategy for managing multiple environments (dev, staging, prod). Two primary approaches exist: **workspaces** and **directory-based separation**. This section provides guidance on when to use each approach.

#### Comparison Table

| Approach | Use When | Advantages | Disadvantages |
| --- | --- | --- | --- |
| **Workspaces** | Identical infrastructure across environments; only variable values differ; small team with clear workflow | Single codebase; easy to switch between environments; built-in Terraform feature | Shared backend configuration; risk of applying to wrong workspace; no visible configuration differences in version control |
| **Directory-based** | Different configurations per environment; team isolation needed; production requires explicit review; compliance requirements | Explicit, reviewable configuration per environment; no risk of workspace confusion; better audit trail; environment-specific customization | Some code duplication; requires discipline to keep shared modules updated |
| **Hybrid** | Large organizations with both simple and complex environments; gradual migration between approaches | Flexibility; can use workspaces for non-production and directories for production | Increased complexity; requires clear documentation of which pattern applies where |

#### Workspace-Based Approach

Workspaces create isolated state files within a single configuration. Each workspace shares the same backend configuration but maintains separate state.

**How workspaces work:**

```bash
# Create a new workspace
terraform workspace new staging

# List available workspaces
terraform workspace list

# Switch to an existing workspace
terraform workspace select prod

# Show current workspace
terraform workspace show
```

**Using `terraform.workspace` for environment-specific values:**

```hcl
locals {
  environment_config = {
    dev = {
      instance_type = "t3.micro"
      instance_count = 1
    }
    staging = {
      instance_type = "t3.small"
      instance_count = 2
    }
    prod = {
      instance_type = "t3.medium"
      instance_count = 3
    }
  }

  config = local.environment_config[terraform.workspace]
}

resource "aws_instance" "app" {
  count         = local.config.instance_count
  instance_type = local.config.instance_type
  # ...
}
```

**When workspaces are appropriate:**

- Infrastructure is identical across environments except for variable values
- Small team with clear communication about which workspace is active
- Non-production environments where accidental applies have limited impact
- Rapid prototyping or development scenarios

**Limitations of workspaces:**

- All environments share the same backend configuration
- No visible difference in repository between environments
- Risk of running `terraform apply` in the wrong workspace
- Difficult to implement environment-specific features or configurations
- Code review cannot distinguish between environment configurations

#### Directory-Based Approach

Directory-based separation uses distinct directories for each environment, each with its own configuration files and backend configuration. Shared logic is extracted into reusable modules.

**Recommended directory structure:**

```text
.
├── modules/                    # Shared reusable modules
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── application/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── dev/
│   │   ├── main.tf            # Calls modules with dev-specific values
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── backend.tf         # Dev-specific backend configuration
│   │   └── terraform.tfvars   # Dev-specific variable values
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── backend.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── backend.tf
│       └── terraform.tfvars
└── README.md
```

**Example environment configuration (`environments/prod/main.tf`):**

```hcl
module "vpc" {
  source = "../../modules/vpc"

  environment = "prod"
  cidr_block  = "10.0.0.0/16"
}

module "application" {
  source = "../../modules/application"

  environment    = "prod"
  vpc_id         = module.vpc.vpc_id
  instance_type  = "t3.medium"
  instance_count = 3
}
```

**When directory separation is preferred:**

- Different configurations per environment (not just variable values)
- Production environments require explicit review and approval
- Team isolation—different teams manage different environments
- Compliance requirements mandate separation of concerns
- Environment-specific features or integrations

**Sharing modules across environment directories:**

- Extract common infrastructure patterns into modules under `modules/`
- Each environment directory calls these modules with environment-specific values
- Modules **SHOULD** be versioned when used across repositories
- Use relative paths (`../../modules/vpc`) for repository-local modules

#### Recommendation

For production use, directory-based separation is **RECOMMENDED** as the default approach because:

1. **Explicit configuration:** Each environment has its own visible, reviewable configuration in version control
2. **Safety:** No risk of accidentally applying changes to the wrong environment
3. **Flexibility:** Easy to implement environment-specific configurations or features
4. **Audit trail:** Git history clearly shows what changed in each environment
5. **Team isolation:** Different teams or approval processes can manage different environments
6. **Compliance:** Easier to demonstrate separation of concerns for auditors

Workspaces **MAY** be used for:

- Development and testing environments where rapid iteration is prioritized
- Scenarios where infrastructure is truly identical across environments
- Small teams with established workspace discipline
- Temporary or ephemeral environments

Teams **SHOULD** document their chosen approach in the repository's README or contributing guide to ensure consistency.

### Resource Targeting

`terraform apply -target` **SHOULD NOT** be used in normal workflows. Resource targeting:

- Creates state drift between targeted and non-targeted resources
- Can leave infrastructure in inconsistent states
- Bypasses dependency validation

Resource targeting is intended **only** for exceptional recovery scenarios where a specific resource must be modified in isolation.

**If targeting is needed regularly**, this indicates the configuration is too large. Split the configuration into smaller, independent modules that can be applied separately.

### Reviewing Plan Output

Before running `terraform apply`, review the plan output carefully. Understanding the plan symbols and identifying warning signs helps prevent unintended infrastructure changes.

**Plan output symbols:**

| Symbol | Meaning | Action |
| --- | --- | --- |
| `+` (green) | Resource will be created | Verify this is intentional |
| `-` (red) | Resource will be destroyed | Verify this is intentional; check for data loss |
| `~` (yellow) | Resource will be updated in-place | Review which attributes are changing |
| `-/+` | Resource will be destroyed and recreated | Investigate why; consider `lifecycle` rules |
| `<=` | Data source will be read | Normal behavior |

**Warning signs to investigate:**

- Unexpected destroys, especially for stateful resources (databases, storage)
- Resources being replaced (`-/+`) when you expected an in-place update
- Changes to resources you didn't modify (may indicate drift or upstream changes)
- Large numbers of changes from a small code modification (may indicate a variable or module change with wide impact)

**Best practice:** Use `terraform plan -out=tfplan` to save the plan, then `terraform apply tfplan` to ensure the exact reviewed plan is applied.

---

## Cross-Stack Data Sharing

When infrastructure is split across multiple independent Terraform configurations (often called "stacks"), you need a mechanism to share data between them. Common scenarios include:

- **Network and application separation:** A networking team manages VPCs/VNets, and application teams need to reference VPC IDs and subnet IDs.
- **Shared services:** Central services (e.g., logging, monitoring) need to be referenced by multiple application stacks.
- **Multi-team ownership:** Different teams own different parts of infrastructure but need to integrate.

### Approaches Comparison

| Approach | Recommendation | Coupling | Security |
| --- | --- | --- | --- |
| Cloud-native parameter stores | **PREFERRED** | Loose | Configurable per-value |
| `terraform_remote_state` data source | Acceptable with caveats | Tight | Full state exposure |
| Hardcoding values | **DISCOURAGED** | None (brittle) | Poor |

### Preferred: Cloud-Native Parameter Stores

Cloud-native parameter stores provide a **loosely coupled** mechanism for sharing configuration values between stacks. Values are explicitly published and consumed, providing clear contracts between teams.

#### AWS: SSM Parameter Store

**Publishing values (network stack):**

```hcl
# outputs.tf - Network stack
output "vpc_id" {
  description = "VPC ID for application stacks"
  value       = aws_vpc.main.id
}

# main.tf - Publish to SSM
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${var.environment}/network/vpc_id"
  type  = "String"
  value = aws_vpc.main.id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/${var.environment}/network/private_subnet_ids"
  type  = "StringList"
  value = join(",", aws_subnet.private[*].id)

  tags = local.common_tags
}
```

**Consuming values (application stack):**

```hcl
# data.tf - Application stack
data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.environment}/network/vpc_id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.environment}/network/private_subnet_ids"
}

locals {
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
}

# Use in resources
resource "aws_instance" "app" {
  subnet_id = local.private_subnet_ids[0]
  # ...
}
```

#### Azure: App Configuration or Key Vault (Data Plane)

**Publishing values (network stack):**

```hcl
resource "azurerm_app_configuration" "main" {
  name                = "appconf-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_app_configuration_key" "vnet_id" {
  configuration_store_id = azurerm_app_configuration.main.id
  key                    = "network/vnet_id"
  value                  = azurerm_virtual_network.main.id
}

resource "azurerm_app_configuration_key" "subnet_ids" {
  configuration_store_id = azurerm_app_configuration.main.id
  key                    = "network/subnet_ids"
  value                  = jsonencode(azurerm_subnet.private[*].id)
}
```

**Consuming values (application stack):**

```hcl
data "azurerm_app_configuration" "main" {
  name                = "appconf-${var.project_name}-${var.environment}"
  resource_group_name = var.shared_resource_group_name
}

data "azurerm_app_configuration_key" "vnet_id" {
  configuration_store_id = data.azurerm_app_configuration.main.id
  key                    = "network/vnet_id"
}

data "azurerm_app_configuration_key" "subnet_ids" {
  configuration_store_id = data.azurerm_app_configuration.main.id
  key                    = "network/subnet_ids"
}

locals {
  vnet_id    = data.azurerm_app_configuration_key.vnet_id.value
  subnet_ids = jsondecode(data.azurerm_app_configuration_key.subnet_ids.value)
}
```

#### GCP: Cloud Storage with Metadata or Runtime Config

> **Note:** GCP does not have a direct equivalent to AWS SSM Parameter Store. For cross-stack configuration sharing, Cloud Storage buckets with JSON configuration files provide a simple, cost-effective approach.

**Publishing values (network stack):**

```hcl
resource "google_storage_bucket" "config" {
  name     = "${var.project_id}-terraform-config"
  location = var.region

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "network_config" {
  name    = "config/${var.environment}/network.json"
  bucket  = google_storage_bucket.config.name
  content = jsonencode({
    vpc_id     = google_compute_network.main.id
    subnet_ids = google_compute_subnetwork.private[*].id
  })
}
```

**Consuming values (application stack):**

```hcl
data "google_storage_bucket_object_content" "network_config" {
  name   = "config/${var.environment}/network.json"
  bucket = "${var.project_id}-terraform-config"
}

locals {
  network_config = jsondecode(data.google_storage_bucket_object_content.network_config.content)
  vpc_id         = local.network_config.vpc_id
  subnet_ids     = local.network_config.subnet_ids
}
```

### Acceptable: terraform_remote_state Data Source

The `terraform_remote_state` data source reads outputs from another Terraform state file. While functional, it creates **tight coupling** between configurations.

```hcl
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "acme-corp-terraform-state"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

# Access outputs from the network stack
locals {
  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}
```

**Caveats when using `terraform_remote_state`:**

- **Tight coupling:** Changes to the source stack's outputs can break consuming stacks.
- **State file access:** Consumers need read access to the entire state file, not just specific outputs.
- **Least Privilege violation:** Consumers gain access to **all** outputs in the source state file, potentially exposing sensitive data not intended for sharing. This over-fetching of permissions violates security best practices.
- **No explicit contract:** No clear interface definition between producer and consumer.
- **Harder to test:** Mocking remote state in tests is more complex than mocking parameter store lookups.

### What to Share (and What Not to Share)

| Share | Examples | Notes |
| --- | --- | --- |
| Resource IDs | VPC ID, Subnet IDs, Security Group IDs | Primary use case |
| ARNs/Resource Names | Role ARNs, Bucket names, Queue ARNs | For cross-account references |
| Endpoints | RDS endpoints, API Gateway URLs | For service discovery |
| Non-sensitive configuration | CIDR blocks, region, environment name | Shared context |

| Do NOT Share | Reason |
| --- | --- |
| Secrets/credentials | Use dedicated secret managers with proper access controls |
| Full resource objects | Exposes unnecessary implementation details |
| Internal implementation details | Creates coupling to internal structure |

### Cross-Stack Data Sharing Best Practices

- **Define explicit contracts:** Document what values are published and their format.
- **Use consistent naming conventions:** Establish a parameter naming scheme (e.g., `/${environment}/${team}/${resource_type}`).
- **Version your contracts:** When changing published values, consider backward compatibility.
- **Prefer loose coupling:** Parameter stores allow consuming stacks to be applied independently of producer stacks (after initial setup).

---

## Provider Management

### Provider Version Constraints

Provider versions **MUST** be constrained in `versions.tf`:

| Pattern | Example | Use Case |
| --- | --- | --- |
| Pessimistic constraint | `~> 6.0` | Allow minor and patch version updates within major 6 (any 6.x.y, but not 7.0.0) |
| Exact version | `= 6.31.0` | Strict reproducibility required |
| Range constraint | `>= 6.0, < 7.0` | Explicit major version bounds (any 6.x, but not 7.0.0+) |

In general, for a major version **M**, use a range of the form `>= M.0, < (M+1).0` to constrain to that major version while allowing all patch and minor updates within it (for example, for **M = 6**: `>= 6.0, < 7.0`).

**Recommended approach:**

```hcl
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
```

### Lock File Management

The `.terraform.lock.hcl` file:

- **MUST** be committed to version control
- **SHOULD** be updated explicitly using `terraform providers lock`
- **MUST** be updated when provider versions change
- **SHOULD** include hashes for all platforms used in CI

```bash
# Update lock file with hashes for multiple platforms
terraform providers lock \
  -platform=linux_amd64 \
  -platform=linux_arm64 \
  -platform=darwin_amd64 \
  -platform=darwin_arm64 \
  -platform=windows_amd64 \
  -platform=windows_arm64
```

> **When to regenerate `.terraform.lock.hcl`:**
>
> Regenerate the lock file **only** when you intentionally change provider versions, add/remove providers, or add new execution platforms (e.g., new CI OS/architecture). Avoid running `terraform init -upgrade` unless you intend to update providers. After regeneration, review diffs and commit the updated lock file.

### Pessimistic Constraints

Use the pessimistic constraint operator (`~>`) for providers to allow patch updates while preventing breaking changes:

```hcl
# Good: Allows 6.x updates but not 7.0
version = "~> 6.0"

# Good: Allows 6.31.x updates but not 6.32.0
version = "~> 6.31.0"
```

### Provider Aliasing

Provider aliasing enables multiple instances of the same provider for multi-region or multi-account deployments. Use aliases when resources need to be created in different regions, accounts, or with different configurations.

**Common use cases:**

- Disaster recovery across regions
- Cross-region replication (S3, RDS, etc.)
- Multi-account architectures
- Resources requiring different provider configurations

**AWS Example - Defining aliased providers:**

```hcl
# providers.tf

provider "aws" {
  region = "us-east-1"  # e.g., us-east-1
  # Default provider (no alias)
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"  # e.g., us-west-2
}

provider "aws" {
  alias  = "eu"
  region = "eu-west-1"  # e.g., eu-west-1
}
```

**AWS Example - Using aliased providers in resources:**

```hcl
# Use default provider
resource "aws_s3_bucket" "primary" {
  bucket = "acme-corp-primary-data"
}

# Use aliased provider
resource "aws_s3_bucket" "replica" {
  provider = aws.west
  bucket   = "acme-corp-replica-data"
}
```

**Azure Example - Defining aliased providers:**

```hcl
# providers.tf

provider "azurerm" {
  features {}
  subscription_id = var.primary_subscription_id
  # Default provider (no alias)
}

provider "azurerm" {
  alias           = "secondary"
  features {}
  subscription_id = var.secondary_subscription_id
}
```

**Azure Example - Using aliased providers in resources:**

```hcl
# Use default provider
resource "azurerm_storage_account" "primary" {
  name                     = "stacmeprimary"
  resource_group_name      = azurerm_resource_group.primary.name
  location                 = azurerm_resource_group.primary.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Use aliased provider
resource "azurerm_storage_account" "secondary" {
  provider                 = azurerm.secondary
  name                     = "stacmesecondary"
  resource_group_name      = azurerm_resource_group.secondary.name
  location                 = azurerm_resource_group.secondary.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

**GCP Example - Defining aliased providers:**

```hcl
# providers.tf

provider "google" {
  project = var.primary_project_id
  region  = "us-central1"
  # Default provider (no alias)
}

provider "google" {
  alias   = "europe"
  project = var.primary_project_id
  region  = "europe-west1"
}

provider "google" {
  alias   = "secondary_project"
  project = var.secondary_project_id
  region  = "us-west1"
}
```

**GCP Example - Using aliased providers in resources:**

```hcl
# Use default provider
resource "google_storage_bucket" "primary" {
  name     = "acme-corp-primary-data"
  location = "US"
}

# Use aliased provider for different region
resource "google_storage_bucket" "europe" {
  provider = google.europe
  name     = "acme-corp-europe-data"
  location = "EU"
}
```

**Passing providers to modules:**

```hcl
module "vpc_west" {
  source = "./modules/vpc"

  providers = {
    aws = aws.west
  }

  cidr_block = "10.1.0.0/16"
}
```

### Module Provider Configuration with configuration_aliases

When a module needs to accept multiple provider configurations (e.g., for multi-region deployments), it **MUST** declare the expected provider configurations using `configuration_aliases` in the `required_providers` block.

**Why configuration_aliases is required:**

- Modules **SHOULD NOT** define provider configurations directly; provider configurations **MUST** be defined in root modules. Terraform **CAN** accept provider blocks in child modules only as a legacy pattern and imposes limitations on such modules.
- Modules that use provider aliases internally must declare which aliases they expect
- This creates an explicit contract between the module and its callers

**Module declaration example:**

```hcl
# modules/multi-region-storage/versions.tf

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
      configuration_aliases = [aws.primary, aws.secondary]
    }
  }
}
```

**Using aliased providers in module resources:**

```hcl
# modules/multi-region-storage/main.tf

resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "${var.name}-primary"
}

resource "aws_s3_bucket" "secondary" {
  provider = aws.secondary
  bucket   = "${var.name}-secondary"
}
```

**Calling module with provider mappings:**

```hcl
# Root module

module "multi_region_storage" {
  source = "./modules/multi-region-storage"

  providers = {
    aws.primary   = aws.us_east
    aws.secondary = aws.eu_west
  }

  name = "my-storage"
}
```

**Key requirements:**

- The `configuration_aliases` list **MUST** include all provider aliases used within the module
- Calling modules **MUST** map their provider configurations to the expected aliases
- Provider alias names in the module do not need to match the caller's alias names—the `providers` argument handles the mapping

### Cross-Account and Service Account Patterns

Enterprise environments often require accessing resources across multiple accounts, subscriptions, or projects. This section documents provider-specific authentication patterns for cross-account access.

#### AWS: Assume Role Configuration

The `assume_role` block enables Terraform to assume an IAM role in a different AWS account, providing temporary credentials for cross-account access. This pattern **SHOULD** be used instead of static credentials for cross-account AWS access.

**Basic assume_role configuration:**

```hcl
provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::ACCOUNT_ID:role/TerraformRole"
    session_name = "terraform-session"
    external_id  = var.external_id  # Optional, for third-party access
  }
}
```

**When to use assume_role:**

- Cross-account resource management from a central deployment account
- Implementing least-privilege access patterns
- Enabling CI/CD pipelines to access multiple accounts with a single identity
- Third-party access scenarios (using `external_id` for additional security)

**IAM trust relationship requirement:**

The target role must have a trust policy that allows the source principal to assume it. The trust policy should specify the source account, role, or user that is permitted to assume the role.

**Multi-account pattern with provider aliases:**

```hcl
provider "aws" {
  alias  = "production"
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::PROD_ACCOUNT_ID:role/TerraformRole"
    session_name = "terraform-prod"
  }
}

provider "aws" {
  alias  = "staging"
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::STAGING_ACCOUNT_ID:role/TerraformRole"
    session_name = "terraform-staging"
  }
}

resource "aws_s3_bucket" "prod_bucket" {
  provider = aws.production
  bucket   = "my-prod-bucket"
}

resource "aws_s3_bucket" "staging_bucket" {
  provider = aws.staging
  bucket   = "my-staging-bucket"
}
```

#### Azure: Subscription and Tenant Patterns

Azure provider configuration supports multi-subscription and multi-tenant scenarios through explicit subscription and tenant IDs.

**Basic multi-subscription configuration:**

```hcl
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id  # Required for multi-tenant scenarios

  # Skip provider registration when lacking permissions
  skip_provider_registration = true  # Use when service principal lacks registration permissions
}
```

**When to use `skip_provider_registration = true`:**

- Service principal lacks `Microsoft.Authorization/*/register/action` permission
- Deploying to shared subscriptions where resource providers are pre-registered
- Operating in environments with strict permission boundaries

> **Note:** When using `skip_provider_registration = true`, the required resource providers **MUST** already be registered in the subscription. Terraform will fail if it attempts to create resources for unregistered providers.

**Multi-subscription pattern with provider aliases:**

```hcl
provider "azurerm" {
  alias = "production"
  features {}

  subscription_id = var.production_subscription_id
  tenant_id       = var.tenant_id
}

provider "azurerm" {
  alias = "shared_services"
  features {}

  subscription_id = var.shared_services_subscription_id
  tenant_id       = var.tenant_id
}

resource "azurerm_resource_group" "prod" {
  provider = azurerm.production
  name     = "rg-prod-app"
  location = "eastus"
}

resource "azurerm_resource_group" "shared" {
  provider = azurerm.shared_services
  name     = "rg-shared-networking"
  location = "eastus"
}
```

#### GCP: Service Account Impersonation

Service account impersonation allows Terraform to act as a service account without requiring its key file. This pattern **SHOULD** be preferred over service account key files.

**Basic impersonation configuration:**

```hcl
provider "google" {
  project = var.project_id
  region  = var.region

  # Impersonate a service account instead of using default credentials
  impersonate_service_account = "terraform@${var.project_id}.iam.gserviceaccount.com"
}
```

**When to use impersonation:**

- CI/CD pipelines where the runner uses a less-privileged service account
- Local development with user credentials that need elevated access
- Implementing least-privilege access patterns
- Avoiding long-lived service account key files

**Required IAM permissions for impersonation:**

The calling identity must have `roles/iam.serviceAccountTokenCreator` on the target service account, or the `iam.serviceAccounts.getAccessToken` permission.

**Benefits over service account keys:**

- No key rotation required—credentials are short-lived
- Audit trail shows both the calling identity and impersonated account
- Reduced risk of credential exposure
- Easier to revoke access by removing IAM bindings

**Multi-project pattern with impersonation:**

```hcl
provider "google" {
  alias   = "production"
  project = var.production_project_id
  region  = var.region

  impersonate_service_account = "terraform@${var.production_project_id}.iam.gserviceaccount.com"
}

provider "google" {
  alias   = "staging"
  project = var.staging_project_id
  region  = var.region

  impersonate_service_account = "terraform@${var.staging_project_id}.iam.gserviceaccount.com"
}
```

#### Cross-Account Pattern Summary

| Provider | Pattern | Use Case |
| --- | --- | --- |
| AWS | `assume_role` | Access resources in different AWS accounts |
| Azure | Multiple providers with different `subscription_id` | Manage resources across subscriptions |
| GCP | `impersonate_service_account` or project-per-provider | Access resources with elevated permissions |

#### Security Considerations for Cross-Account Access

Cross-account patterns **MUST** follow security best practices:

- **Prefer short-lived credentials:** `assume_role` and `impersonate_service_account` **SHOULD** be used instead of static access keys or service account key files
- **Document requirements:** Cross-account access patterns **MUST** be documented in module README files when modules require cross-account permissions
- **Use external_id for third parties:** When granting cross-account access to third parties in AWS, use `external_id` to prevent confused deputy attacks
- **Apply least-privilege:** Cross-account roles and service accounts **SHOULD** have only the permissions required for their specific tasks
- **Audit cross-account access:** Enable logging to track which identities are assuming roles or impersonating service accounts

---

## Security Best Practices

### Secret Management

Secrets **MUST NEVER** appear in Terraform code or version control.

#### Prohibited Patterns

The following patterns are **PROHIBITED**:

```hcl
# NEVER DO THIS
variable "db_password" {
  default = "SuperSecretPassword123!"  # PROHIBITED
}

resource "aws_db_instance" "main" {
  password = "hardcoded-password"  # PROHIBITED
}
```

### No Secret Defaults

Sensitive variables **MUST NOT** have default values:

```hcl
# Correct: No default for secrets
variable "database_password" {
  description = "Database password. Set via TF_VAR_database_password."
  type        = string
  sensitive   = true
  # No default!
}
```

### Approved Secret Patterns

**Pattern 1: Environment Variables**

```hcl
variable "db_password" {
  description = "Database password. Set via TF_VAR_db_password environment variable."
  type        = string
  sensitive   = true
}
```

```bash
# Choose one of the following exports based on your cloud provider:

# AWS
export TF_VAR_db_password="$(aws secretsmanager get-secret-value --secret-id database-password --query SecretString --output text)"

# Azure
export TF_VAR_db_password="$(az keyvault secret show --vault-name kv-acme-prod --name database-password --query value -o tsv)"

# GCP
export TF_VAR_db_password="$(gcloud secrets versions access latest --secret=database-password)"

# Then run terraform apply
terraform apply
```

**Pattern 2: Cloud Provider Secret Managers**

**AWS Example - Secrets Manager:**

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "database-password"
}

resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

**Azure Example - Key Vault:**

```hcl
data "azurerm_key_vault" "main" {
  name                = "kv-acme-prod"
  resource_group_name = "rg-terraform-state"
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  key_vault_id = data.azurerm_key_vault.main.id
}

resource "azurerm_mssql_server" "main" {
  administrator_login_password = data.azurerm_key_vault_secret.db_password.value
  # ... other configuration
}
```

**GCP Example - Secret Manager:**

```hcl
data "google_secret_manager_secret_version" "db_password" {
  secret  = "database-password"
  project = var.project_id
}

resource "google_sql_database_instance" "main" {
  # Password accessed via: data.google_secret_manager_secret_version.db_password.secret_data
  # ... other configuration
}
```

**Pattern 3: HashiCorp Vault (Provider-Agnostic)**

> **Note:** This example uses `vault_generic_secret` which works with both KV v1 and KV v2 secrets engines. For KV v2, include `/data/` in the path (e.g., `secret/data/database`). The data is accessed via `.data["key"]` regardless of KV version.

```hcl
data "vault_generic_secret" "db_creds" {
  # Path MUST be customized for your Vault secret location.
  path = "secret/data/production/database"
}

# AWS Example
resource "aws_db_instance" "main" {
  username = data.vault_generic_secret.db_creds.data["username"]
  password = data.vault_generic_secret.db_creds.data["password"]
}

# Azure Example
resource "azurerm_mssql_server" "main" {
  administrator_login          = data.vault_generic_secret.db_creds.data["username"]
  administrator_login_password = data.vault_generic_secret.db_creds.data["password"]
  # ... other configuration
}

# GCP Example
resource "google_sql_user" "main" {
  name     = data.vault_generic_secret.db_creds.data["username"]
  password = data.vault_generic_secret.db_creds.data["password"]
  instance = google_sql_database_instance.main.name
}
```

### Sensitive Variable Marking

Variables containing sensitive data **MUST** be marked:

```hcl
variable "api_key" {
  description = "API key for external service"
  type        = string
  sensitive   = true  # REQUIRED for secrets
}

output "connection_string" {
  description = "Database connection string (contains credentials)"
  value       = local.connection_string
  sensitive   = true  # REQUIRED if contains secrets
}
```

### State Security

State files contain sensitive data and **MUST** be protected.

#### Requirements

1. **Encryption at rest:** State backends **MUST** enable encryption
2. **Access control:** State files **MUST** be accessible only to authorized users/roles
3. **No local state in production:** Local state files **MUST NOT** be used for production
4. **State locking:** Backends **MUST** support state locking

#### Backend Security Configuration

**AWS Example:**

```hcl
terraform {
  backend "s3" {
    bucket         = "acme-corp-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true                    # REQUIRED
    dynamodb_table = "terraform-locks"  # REQUIRED for locking
    # Use IAM role or credentials from environment
  }
}
```

**Azure Example:**

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stacmeterraform"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
    # Encryption and locking are enabled by default on Azure Storage
    # Use managed identity or service principal for authentication
  }
}
```

**GCP Example:**

```hcl
terraform {
  backend "gcs" {
    bucket = "acme-corp-terraform-state"
    prefix = "prod"
    # Encryption and locking are enabled by default on GCS
    # Use service account for authentication
  }
}
```

### Least-Privilege Principles

IAM policies and resource permissions **MUST** follow least-privilege:

#### IAM Policy Guidelines

- Grant only required permissions
- Use resource-level restrictions when possible
- Avoid wildcard actions (`*`) except when truly needed
- Use conditions to further restrict access

**AWS Example - Specific permissions (GOOD):**

```hcl
resource "aws_iam_policy" "s3_reader" {
  name = "s3-reader"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data.arn,
          "${aws_s3_bucket.data.arn}/*"
        ]
      }
    ]
  })
}
```

**AWS Example - Overly permissive (BAD):**

```hcl
resource "aws_iam_policy" "bad_example" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:*"]       # TOO BROAD
      Resource = ["*"]           # TOO BROAD
    }]
  })
}
```

**Azure Example - Specific permissions (GOOD):**

```hcl
resource "azurerm_role_assignment" "storage_reader" {
  scope                = azurerm_storage_account.data.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
```

**Azure Example - Overly permissive (BAD):**

```hcl
resource "azurerm_role_assignment" "bad_example" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"  # TOO BROAD - grants write access to entire subscription
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
```

**GCP Example - Specific permissions (GOOD):**

```hcl
resource "google_storage_bucket_iam_member" "viewer" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.app.email}"
}
```

**GCP Example - Overly permissive (BAD):**

```hcl
resource "google_project_iam_member" "bad_example" {
  project = var.project_id
  role    = "roles/editor"  # TOO BROAD - grants write access to entire project
  member  = "serviceAccount:${google_service_account.app.email}"
}
```

### Sensitive Values in Meta-Arguments

Values used in `for_each` keys and `count` expressions appear in Terraform state and plan output, even if the source variable is marked `sensitive = true`. This creates a security risk where sensitive data can be exposed.

**Security requirements:**

- Sensitive values **MUST NOT** be used as `for_each` keys
- Sensitive values **MUST NOT** be used in `count` conditions where the value itself is exposed
- Use non-sensitive identifiers as keys and reference sensitive values only in resource attributes

**Anti-pattern (sensitive values exposed in state):**

```hcl
# BAD: Sensitive value used as for_each key - names will appear in state
variable "secret_names" {
  type      = list(string)
  sensitive = true
}

resource "aws_secretsmanager_secret" "secrets" {
  for_each = toset(var.secret_names)  # Keys leak to state!
  name     = each.key
}
```

**Correct pattern (non-sensitive keys):**

```hcl
# GOOD: Use non-sensitive identifiers as keys
variable "secrets" {
  type = map(object({
    name  = string
    value = string
  }))
  sensitive = true
}

resource "aws_secretsmanager_secret" "secrets" {
  for_each = { for k, v in var.secrets : k => v.name }
  name     = each.value  # each.key is the non-sensitive identifier
}
```

### Ephemeral Values

Terraform 1.10 introduced `ephemeral` values—a mechanism for handling sensitive data that should never be persisted to state. Unlike `sensitive` values (which are stored in state but redacted in output), ephemeral values are never written to state at all.

#### When to Use Ephemeral vs Sensitive

| Attribute | Behavior | Use Case |
| --- | --- | --- |
| `sensitive = true` | Value is stored in state but redacted in plan/apply output | Secrets that Terraform needs to track for drift detection |
| `ephemeral = true` | Value is never written to state | Temporary tokens, session credentials, values that should not persist |

**Key constraint:** Ephemeral values **MUST NOT** be used in resource arguments that persist to state. They are intended for use in providers, provisioners, and other contexts where the value is consumed but not stored.

#### Ephemeral Variable Declaration

```hcl
variable "temporary_token" {
  description = "Short-lived authentication token for provider configuration."
  type        = string
  ephemeral   = true  # Value is never written to state
}

variable "session_credentials" {
  description = "Temporary session credentials that should not persist."
  type = object({
    access_key    = string
    secret_key    = string
    session_token = string
  })
  ephemeral = true
}
```

#### Ephemeral Output Declaration

```hcl
output "generated_token" {
  description = "Token generated during apply (not persisted to state)."
  value       = local.computed_token
  ephemeral   = true
}
```

#### Use Cases for Ephemeral Values

- **Provider authentication:** Temporary tokens used to authenticate providers that should not persist in state
- **Session credentials:** Short-lived credentials from assume-role operations
- **One-time values:** Tokens or secrets used during provisioning but not needed afterward
- **Compliance requirements:** Values that organizational policy prohibits from being stored

> **Note:** Ephemeral values require Terraform 1.10.0 or later. For older versions, use `sensitive = true` and implement additional state protection measures.

### Sensitive Output Exposure in CLI

Marking outputs as `sensitive = true` prevents values from appearing in `terraform plan` and `terraform apply` output, but it **does not** prevent programmatic access via certain CLI commands:

- `terraform output -json` — Returns all outputs, and sensitive values are present in the JSON payload
- `terraform output -raw <name>` — Prints the raw value of the named output, including sensitive values, in plaintext
- `terraform output <name>` — Prints non-sensitive outputs in plaintext; sensitive outputs are redacted unless you use `-raw` or `-json`
- `terraform show -json` — When used to show **state** (current or historical), the JSON output can include sensitive values from that state; when used to show a **plan** file, Terraform intentionally redacts/omits sensitive values from the plan JSON

This behavior is intentional—it allows programmatic access to sensitive values when needed (primarily via state and outputs). However, it creates significant security risks in CI/CD pipelines.

**CI/CD Security Implications:**

When accessing sensitive outputs in CI/CD pipelines:

- **DO NOT** log the output of `terraform output -json` directly
- Use targeted output access: `terraform output -raw <name>` for single values
- Pipe sensitive values directly to consumers without intermediate logging
- Consider using external secret managers instead of Terraform outputs for highly sensitive values

**Anti-pattern:**

```bash
# BAD: Logs all outputs including sensitive values
terraform output -json | tee outputs.json

# BAD: May appear in CI logs
echo "Database password: $(terraform output -raw database_password)"
```

**Recommended patterns:**

```bash
# GOOD: Targeted access without logging
DB_PASSWORD=$(terraform output -raw database_password)

# GOOD: Direct pipe to consumer without intermediate storage
terraform output -raw rendered_manifest | kubectl apply -f -

# GOOD: Mask in CI systems that support it (GitHub Actions example)
echo "::add-mask::$(terraform output -raw api_key)"
API_KEY=$(terraform output -raw api_key)
```

**Best practices:**

- Use CI platform secret masking features when available
- Prefer external secret managers (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault) for highly sensitive values
- Audit CI pipeline logs to ensure sensitive values are not exposed
- Consider using `nonsensitive()` function only when you explicitly need to expose a value and understand the security implications

### Security Scanning

Security scanning tools **SHOULD** be integrated into the development workflow.

#### Recommended Tools

| Tool | Purpose | Integration | Notes |
| --- | --- | --- | --- |
| `trivy` | Comprehensive security scanning | Pre-commit, CI | Recommended; successor to tfsec |
| `checkov` | Policy-as-code scanning | Pre-commit, CI | |
| `terrascan` | Security and compliance | CI | |
| `tfsec` | Static security analysis | Pre-commit, CI | Legacy; now part of Trivy |

> **Note:** `tfsec` has been absorbed into Aqua Security's `trivy` and is now in maintenance mode. New projects **SHOULD** use `trivy` for Terraform security scanning. Existing workflows using `tfsec` will continue to work but **SHOULD** plan migration to `trivy`.

#### Pre-commit Integration Example

```yaml
- repo: https://github.com/antonbabenko/pre-commit-terraform
  rev: v1.105.0
  hooks:
    - id: terraform_trivy  # Recommended for new projects
    - id: terraform_checkov
    # - id: terraform_tfsec  # Legacy; use terraform_trivy instead
```

---

## Testing with Terraform Test

Terraform's native test framework (introduced in Terraform 1.6) provides a way to validate configurations without external testing tools. This section documents testing conventions that integrate with the coding standards in this guide.

> **Note:** Terraform tests require Terraform 1.6.0 or later. Mock providers require Terraform 1.7.0 or later. For older Terraform versions, consider Terratest or other external testing frameworks.

### Test File Naming

Test files **MUST** use the `.tftest.hcl` extension:

- `basic.tftest.hcl`
- `validation.tftest.hcl`
- `integration.tftest.hcl`

### Test File Location

Test files **SHOULD** be placed in a `tests/` directory within the module:

```text
modules/
└── vpc/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── versions.tf
    ├── README.md
    └── tests/
        ├── basic.tftest.hcl
        ├── validation.tftest.hcl
        └── integration.tftest.hcl
```

**Alternative:** Tests alongside configuration:

```text
modules/
└── vpc/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── vpc.tftest.hcl
    └── vpc_validation.tftest.hcl
```

### Test Structure

Terraform test files use HCL syntax with specific blocks.

#### Basic Test Structure

```hcl
# tests/basic.tftest.hcl

# Variables block (optional) - Set values for tests
variables {
  environment = "test"
  vpc_cidr    = "10.0.0.0/16"
}

# Run block - Defines a test scenario
run "creates_vpc_with_correct_cidr" {
  command = plan  # or apply

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block does not match expected value"
  }
}

run "creates_required_subnets" {
  command = plan

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Expected 3 private subnets"
  }
}
```

#### Test Block Reference

| Block | Purpose | Requirement |
| --- | --- | --- |
| `variables {}` | Set input variable values for tests | MAY |
| `provider {}` | Configure provider for tests (e.g., mock) | MAY |
| `run "name" {}` | Define a test scenario | MUST (at least one) |
| `assert {}` | Define a test assertion within a run | MUST (at least one per run) |
| `expect_failures` | Expect specific resources/outputs to fail | MAY |

### Test Assertions

Each `run` block **MUST** include at least one `assert`:

```hcl
run "instance_has_correct_type" {
  command = plan

  assert {
    condition     = aws_instance.main.instance_type == var.instance_type
    error_message = "Instance type mismatch"
  }

  assert {
    condition     = aws_instance.main.tags["Environment"] == "test"
    error_message = "Instance must have Environment tag"
  }
}
```

### Testing Variable Validation

Test validation rules with `expect_failures`:

```hcl
run "rejects_invalid_environment" {
  command = plan

  variables {
    environment = "invalid"  # Should fail validation
  }

  expect_failures = [
    var.environment
  ]
}

run "accepts_valid_environment" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = var.environment == "prod"
    error_message = "Environment should be prod"
  }
}
```

### Testing Outputs

```hcl
run "outputs_vpc_id" {
  command = apply

  assert {
    condition     = output.vpc_id != null && output.vpc_id != ""
    error_message = "vpc_id output must not be empty"
  }
}

run "outputs_correct_subnet_count" {
  command = apply

  assert {
    condition     = length(output.subnet_ids) == 3
    error_message = "Expected 3 subnet IDs in output"
  }
}
```

### Mock Providers

For unit testing without real infrastructure, use mock providers:

> **Note:** The `mock_provider` block requires Terraform 1.7.0 or later. For earlier versions of the test framework (Terraform 1.6.x), tests must use real provider credentials or skip provider-dependent tests.

**AWS Example:**

```hcl
# tests/unit.tftest.hcl

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
}

run "uses_all_availability_zones" {
  command = plan

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Should create subnet in each AZ"
  }
}
```

**Azure Example:**

```hcl
# tests/unit.tftest.hcl

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000002"
      subscription_id = "00000000-0000-0000-0000-000000000001"
    }
  }
}

run "resource_group_has_correct_location" {
  command = plan

  assert {
    condition     = azurerm_resource_group.main.location == "eastus"
    error_message = "Resource group should be in eastus"
  }
}
```

**GCP Example:**

```hcl
# tests/unit.tftest.hcl

mock_provider "google" {
  mock_data "google_compute_zones" {
    defaults = {
      names = ["us-central1-a", "us-central1-b", "us-central1-c"]
    }
  }
}

run "uses_all_compute_zones" {
  command = plan

  assert {
    condition     = length(google_compute_instance.main) == 3
    error_message = "Should create instance in each zone"
  }
}
```

### Unit Tests

Unit tests use `command = plan` (the default):

- Do NOT create real resources
- Fast execution
- Test configuration logic, not cloud provider behavior

```hcl
run "unit_test_example" {
  command = plan  # Explicit, though it's the default

  assert {
    condition     = aws_instance.main.instance_type == var.instance_type
    error_message = "Instance type mismatch"
  }
}
```

### Integration Tests

Integration tests use `command = apply`:

- Create and destroy real resources
- Slower execution
- Test actual infrastructure behavior
- Require valid provider credentials

```hcl
run "integration_test_example" {
  command = apply  # Creates real resources

  assert {
    condition     = aws_instance.main.id != ""
    error_message = "Instance should be created"
  }
}
```

**Best Practice:** Run unit tests (`plan`) frequently during development. Run integration tests (`apply`) in CI or before releases.

### Running Tests

#### Basic Test Execution

```bash
# Run all tests in current directory
terraform test

# Run tests with verbose output
terraform test -verbose

# Run specific test file
terraform test -filter=tests/basic.tftest.hcl
```

#### CI Integration

```yaml
# .github/workflows/terraform-ci.yml (test job)
- name: Terraform Init
  run: terraform init

- name: Terraform Test
  run: terraform test -verbose
```

### What to Test

Tests **SHOULD** cover:

| Category | What to Test | Example |
| --- | --- | --- |
| **Variable validation** | Custom validation rules work correctly | Invalid environment rejected |
| **Computed values** | Locals and expressions compute correctly | CIDR calculations |
| **Resource configuration** | Resources have expected attributes | Instance type, tags |
| **Output values** | Outputs contain expected values | VPC ID not empty |
| **Module integration** | Modules work together | VPC + subnets + security groups |
| **Edge cases** | Boundary conditions | Zero instances, empty lists |

**Not to test:**

- Cloud provider behavior (e.g., "does AWS actually create an EC2?")
- Terraform core functionality
- External service availability

---

## Documentation Standards

### Module README Requirements

Every module **MUST** include a `README.md` with:

1. **Description** — What the module does
2. **Usage example** — Minimal working example
3. **Requirements** — Terraform and provider versions
4. **Inputs** — All variables with descriptions
5. **Outputs** — All outputs with descriptions

#### README Template

````markdown
# Module Name

Brief description of what this module creates.

## Usage

```hcl
module "example" {
  source = "./modules/example"

  required_variable = "value"
}
```

## Requirements

| Name | Version |
| --- | --- |
| terraform | >= 1.6.0 |
| aws | ~> 6.0 |

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | --- |
| required_variable | Description here | `string` | n/a | yes |
| optional_variable | Description here | `string` | `"default"` | no |

## Outputs

| Name | Description |
| --- | --- |
| output_name | Description of output |
````

**Note:** Consider using `terraform-docs` to generate input/output tables automatically.

### Inline Comment Conventions

Comments **SHOULD** explain "why," not "what."

#### Single-Line Comments

Use `#` for single-line comments:

```hcl
# Enable encryption to meet compliance requirements (SOC2)
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  # ...
}
```

#### Block Comments

Use `/* */` sparingly for multi-line explanations:

```hcl
/*
 * This security group allows inbound traffic from the corporate VPN.
 * CIDR ranges are managed by the network team and should not be
 * modified without their approval.
 */
resource "aws_security_group" "vpn_access" {
  # ...
}
```

### TODO Comment Format

Use standardized TODO format:

```hcl
# TODO(username): Migrate to new VPC module after v2.0 release
# TODO(team-name): Add support for IPv6 when available
```

### Error Message Best Practices

Error messages in `validation`, `precondition`, `postcondition`, and `assert` blocks **MUST** be actionable and help users understand how to fix the problem.

**Requirements:**

- Error messages **MUST** be actionable and tell the user how to fix the problem
- Error messages **SHOULD** include the actual value that failed validation when possible
- Error messages **SHOULD** reference valid options or acceptable ranges
- Error messages **MUST NOT** expose sensitive values

**Validation block examples:**

```hcl
# Poor: Not actionable
validation {
  condition     = contains(["dev", "staging", "prod"], var.environment)
  error_message = "Invalid environment."
}

# Good: Actionable with valid options
validation {
  condition     = contains(["dev", "staging", "prod"], var.environment)
  error_message = "Environment must be one of: dev, staging, prod. Received: ${var.environment}"
}
```

**Postcondition examples:**

```hcl
# Poor: No context
postcondition {
  condition     = self.public_ip != null
  error_message = "No public IP."
}

# Good: Explains what to check
postcondition {
  condition     = self.public_ip != null
  error_message = "Instance must have a public IP assigned. Verify that the subnet has map_public_ip_on_launch enabled or associate an Elastic IP."
}
```

---

## Common Anti-Patterns to Avoid

This section consolidates common anti-patterns to help developers avoid frequent mistakes. Each anti-pattern links to detailed guidance elsewhere in this document.

| Anti-Pattern | Why It's Problematic | Correct Approach |
| --- | --- | --- |
| Hardcoded secrets in `.tf` files | Secrets exposed in version control and state | Use environment variables or secret managers → [Secret Management](#secret-management) |
| Using `terraform apply -target` regularly | Creates state drift and inconsistent infrastructure | Split into smaller, independent configurations → [Resource Targeting](#resource-targeting) |
| Redundant `depends_on` for inferable dependencies | Adds noise and can mask actual dependency issues | Let Terraform infer dependencies from references → [Explicit Dependencies](#explicit-dependencies) |
| Using `count` with collections that may reorder | Index shifts cause unintended resource recreation | Use `for_each` with stable keys → [for_each vs count](#for_each-vs-count) |
| Wildcard IAM actions (`"*"`) | Violates least-privilege; security risk | Specify exact required actions → [IAM Policy Guidelines](#iam-policy-guidelines) |
| Local state in team/production environments | No locking, no encryption, easily lost | Configure remote backend → [Remote Backend Configuration](#remote-backend-configuration) |
| Committing `.tfstate` files to version control | Exposes sensitive data; causes merge conflicts | Add to `.gitignore`; use remote backend → [State File Exclusion](#state-file-exclusion) |
| Using `try()` without understanding failure modes | Silently masks errors that should be investigated | Document expected failures; consider explicit null checks |
| Overly complex expressions in resource blocks | Reduces readability; hard to debug | Extract to `locals` with descriptive names |
| Default values for sensitive variables | Encourages insecure deployments | Require explicit values; no defaults for secrets → [No Secret Defaults](#no-secret-defaults) |

---

## Troubleshooting Common Issues

This section provides guidance for resolving common Terraform errors and issues. Each entry includes the error message or symptom, cause, solution, and prevention strategies.

### Error: Error acquiring the state lock

**Symptom:**

```text
Error: Error acquiring the state lock

Error message: ConditionalCheckFailedException: The conditional request failed
Lock Info:
  ID:        a1b2c3d4-e5f6-7890-abcd-ef1234567890
  Path:      terraform.tfstate
  Operation: OperationTypePlan
  Who:       user@hostname
  Version:   1.7.0
  Created:   2026-01-15 10:30:00.000000000 +0000 UTC
```

**Cause:** A previous Terraform operation was interrupted (crash, network failure, timeout), or another user/process is running Terraform concurrently against the same state file.

**Solution:**

1. **Verify no other operations are running.** Check with your team and CI/CD system to confirm no other Terraform operations are in progress.
2. **If confirmed safe, force-unlock the state:**

   ```bash
   terraform force-unlock a1b2c3d4-e5f6-7890-abcd-ef1234567890
   ```

3. **If in CI/CD,** check for stuck or parallel jobs that may be holding the lock.

**Prevention:**

- Implement a single-operator policy or use CI/CD serialization to prevent concurrent operations
- Configure appropriate timeouts for long-running operations
- Use CI/CD pipelines with proper concurrency controls

> **Warning:** Never force-unlock a state if another operation is genuinely in progress. This can cause state corruption.

### Error: Provider configuration not present

**Symptom:**

```text
Error: Provider configuration not present

To work with aws_instance.example its original provider configuration at
provider["registry.terraform.io/hashicorp/aws"] is required, but it has been removed.
```

**Cause:** A resource exists in the state file, but the provider configuration that created it has been removed from the Terraform code.

**Solution:**

1. **Re-add the provider configuration** if the resource should still be managed:

   ```hcl
   provider "aws" {
     region = "us-east-1"
   }
   ```

2. **Remove the orphaned resource from state** if it was intentionally deleted:

   ```bash
   terraform state rm aws_instance.example
   ```

3. **Use a `removed` block** (Terraform 1.7+) to cleanly remove from state without destroying:

   ```hcl
   removed {
     from = aws_instance.example

     lifecycle {
       destroy = false
     }
   }
   ```

**Prevention:**

- Use `moved` blocks when refactoring resources
- Never remove provider configurations while resources using them still exist in state
- Review `terraform plan` output carefully before removing providers

### Error: Cycle detected

**Symptom:**

```text
Error: Cycle: aws_security_group.a, aws_security_group.b
```

**Cause:** Circular dependency between resources where resource A depends on resource B, and resource B depends on resource A.

**Solution:**

1. **Identify the cycle** from the error message—Terraform lists the resources involved
2. **Restructure to break the cycle:**
   - Use separate `aws_security_group_rule` resources instead of inline rules:

     ```hcl
     resource "aws_security_group" "a" {
       name = "sg-a"
       # No inline ingress/egress rules
     }

     resource "aws_security_group" "b" {
       name = "sg-b"
       # No inline ingress/egress rules
     }

     resource "aws_security_group_rule" "a_to_b" {
       type                     = "ingress"
       security_group_id        = aws_security_group.a.id
       source_security_group_id = aws_security_group.b.id
       from_port                = 443
       to_port                  = 443
       protocol                 = "tcp"
     }
     ```

   - Create a shared resource that both can reference
   - Reorganize dependencies to create a one-way relationship

**Prevention:**

- Avoid bidirectional references between resources
- Prefer one-way dependency graphs
- Use separate rule resources instead of inline blocks for security groups
- Review resource relationships before adding cross-references

### Error: Invalid for_each argument

**Symptom:**

```text
Error: Invalid for_each argument

The "for_each" value depends on resource attributes that cannot be determined until apply,
so Terraform cannot predict how many instances will be created.
```

**Cause:** The `for_each` or `count` expression depends on values that are not known until after `terraform apply` runs (e.g., resource IDs, computed attributes).

**Solution:**

1. **Restructure to use values known at plan time:**

   ```hcl
   # Instead of using computed values
   # BAD: for_each = toset(aws_subnet.private[*].id)

   # Use input variables or static values
   # GOOD: for_each = var.subnet_names
   variable "subnet_names" {
     type    = set(string)
     default = ["private-a", "private-b", "private-c"]
   }
   ```

2. **Split into separate configurations** if the dependency is unavoidable
3. **Use `-target` to create dependencies first** (not recommended for regular use):

   ```bash
   terraform apply -target=aws_subnet.private
   terraform apply
   ```

**Prevention:**

- Design `for_each` keys to use static values, input variables, or `locals` computed from known values
- Avoid using computed resource attributes as `for_each` keys
- Consider data architecture that separates resource creation from resource consumption

### Error: Unsupported Terraform Core version

**Symptom:**

```text
Error: Unsupported Terraform Core version

This configuration does not support Terraform version 1.5.0. To proceed,
either choose another supported Terraform version or update this version constraint.
Required version: >= 1.7.0
```

**Cause:** The installed Terraform version does not meet the `required_version` constraint specified in the configuration.

**Solution:**

1. **Install a compatible Terraform version:**

   ```bash
   # Using tfenv (recommended)
   tfenv install 1.7.0
   tfenv use 1.7.0

   # Or download directly from HashiCorp
   # https://releases.hashicorp.com/terraform/
   ```

2. **Update the version constraint** if the older version is acceptable for your use case:

   ```hcl
   terraform {
     required_version = ">= 1.5.0"  # Lowered from 1.7.0
   }
   ```

**Prevention:**

- Document version requirements in README files
- Use version managers like `tfenv` or `asdf` for consistent environments
- Pin Terraform versions in CI/CD pipelines
- Communicate version requirements to team members

### Error: Failed to query available provider packages

**Symptom:**

```text
Error: Failed to query available provider packages

Could not retrieve the list of available versions for provider hashicorp/aws:
could not connect to registry.terraform.io
```

**Cause:** Network connectivity issues, registry temporarily unavailable, proxy misconfiguration, or incorrect provider source specification.

**Solution:**

1. **Check network and proxy settings:**

   ```bash
   # Test registry connectivity
   curl -I https://registry.terraform.io

   # If using a proxy, ensure Terraform can access it
   export HTTPS_PROXY=http://proxy.example.com:8080
   ```

2. **Verify provider source is correct** in `required_providers`:

   ```hcl
   terraform {
     required_providers {
       aws = {
         source  = "hashicorp/aws"  # Verify this is correct
         version = "~> 5.0"
       }
     }
   }
   ```

3. **Wait and retry** if the registry is temporarily unavailable
4. **For air-gapped environments,** use provider mirroring:

   ```bash
   # Create a local mirror
   terraform providers mirror /path/to/mirror

   # Configure Terraform to use the mirror
   # In ~/.terraformrc or terraform.rc:
   provider_installation {
     filesystem_mirror {
       path = "/path/to/mirror"
     }
   }
   ```

**Prevention:**

- Commit `.terraform.lock.hcl` to version control to cache provider checksums
- Consider setting up a provider mirror for reliability in enterprise environments
- Use explicit provider source specifications in all configurations
- Test network connectivity before long Terraform operations

### Debugging with TF_LOG

Terraform provides environment variables for enabling detailed logging when troubleshooting unexpected behavior. These logs can help diagnose issues that don't match specific error patterns.

**TF_LOG levels:**

| Level | Description |
| --- | --- |
| `TRACE` | Most verbose; includes all internal operations |
| `DEBUG` | Detailed information for debugging |
| `INFO` | General operational information |
| `WARN` | Warning messages only |
| `ERROR` | Error messages only |

**Basic usage examples:**

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform plan

# Save logs to a file
export TF_LOG=TRACE
export TF_LOG_PATH=./terraform.log
terraform apply

# Disable logging when done
unset TF_LOG TF_LOG_PATH
```

**Provider-specific logging:**

Use `TF_LOG_PROVIDER` to isolate provider logs from core Terraform logs. This is useful when debugging provider-specific issues without the noise from Terraform core operations:

```bash
export TF_LOG_CORE=WARN
export TF_LOG_PROVIDER=DEBUG
terraform plan
```

**Common debugging scenarios:**

| Scenario | Recommended Level | What to Look For |
| --- | --- | --- |
| API errors | DEBUG | HTTP request/response details |
| Authentication issues | DEBUG | Credential resolution, assume role operations |
| Unexpected resource changes | TRACE | Attribute comparisons, diff calculations |
| Slow operations | INFO | Timing information, API call patterns |

> **Security Warning:** Terraform logs **MAY** contain sensitive information including credentials, API keys, and resource configurations. Log files **MUST NOT** be committed to version control or shared without careful redaction of sensitive data.

**Clean up reminder:**

After debugging, always unset the logging environment variables to avoid log accumulation and potential sensitive data exposure:

```bash
unset TF_LOG TF_LOG_PATH TF_LOG_CORE TF_LOG_PROVIDER
```

---

## Pre-commit Discipline for Terraform

**⚠️ ALWAYS run pre-commit checks before committing Terraform code.**

Pre-commit hooks for Terraform **SHOULD** include:

1. `terraform fmt` — Format check
2. `terraform validate` — Syntax validation
3. `tflint` — Linting
4. Security scanning (optional but recommended)

### Workflow

1. Make Terraform changes
2. Run `terraform fmt -recursive`
3. Run `terraform validate`
4. Run pre-commit hooks: `pre-commit run --all-files`
5. Review and commit ALL auto-fixes as part of your change
6. Push to GitHub

**CI is a safety net, not a substitute for local checks.**

### Pre-commit Configuration

```yaml
# .pre-commit-config.yaml (Terraform section)
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.105.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
        args:
          - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl
```

### TFLint Configuration

This repository's TFLint configuration is defined in `.tflint.hcl` at the repository root. The configuration:

- Enables the `terraform` plugin with the `recommended` preset
- Enforces `snake_case` naming conventions
- Requires documentation for variables and outputs
- Requires type declarations for variables
- Includes commented provider-specific plugins (AWS, Azure, GCP) that **SHOULD** be uncommented based on your cloud provider

When adopting this template, review and customize `.tflint.hcl` for your project's provider requirements.

> **Note:** When enabling provider-specific TFLint plugins (AWS, Azure, GCP), verify that you are using the latest stable versions. The plugin versions in the template may become outdated. Check the [TFLint Ruleset Registry](https://github.com/terraform-linters) for current versions.

### CI Workflow Integration

This repository includes a comprehensive Terraform CI workflow at `.github/workflows/terraform-ci.yml` that enforces these standards automatically:

- **Format Check:** Runs `terraform fmt -check -recursive`
- **Validate:** Runs `terraform init` and `terraform validate` for all Terraform directories
- **Lint:** Runs TFLint with the repository's `.tflint.hcl` configuration
- **Test:** Runs `terraform test` for directories containing `.tftest.hcl` files

The CI workflow uses job dependencies to fail fast: format issues block validation, and validation issues block linting and testing.

For workflow customization options (such as enabling security scanning), see the comments in `.github/workflows/terraform-ci.yml`.

---

## "Done" Definition for Terraform Changes

A Terraform change is considered complete when:

### Code Quality

- [ ] All code passes `terraform fmt -check -recursive`
- [ ] All code passes `terraform validate`
- [ ] All code passes `tflint` without errors
- [ ] Pre-commit hooks pass

### Documentation

- [ ] All variables have `description` attributes
- [ ] All outputs have `description` attributes
- [ ] Sensitive variables/outputs are marked with `sensitive = true`
- [ ] Module `README.md` is updated (if applicable)

### Security

- [ ] No secrets appear in code or tfvars files
- [ ] State backend has encryption enabled
- [ ] IAM policies follow least-privilege
- [ ] Security scanning passes (if configured)

### Testing

- [ ] Variable validation rules are tested
- [ ] Critical outputs are tested
- [ ] Tests pass: `terraform test`

### Version Control

- [ ] `.terraform.lock.hcl` is committed
- [ ] State files are NOT committed
- [ ] All changes are committed with descriptive messages

### CI/CD

- [ ] CI pipeline passes
- [ ] Plan output reviewed (no unexpected changes)

---

## Related Documentation

For additional Terraform guidance beyond this instruction file:

| Topic | Resource |
| --- | --- |
| Terraform Language Documentation | [developer.hashicorp.com/terraform/language](https://developer.hashicorp.com/terraform/language) |
| Terraform CLI Commands | [developer.hashicorp.com/terraform/cli](https://developer.hashicorp.com/terraform/cli) |
| Terraform Test Framework | [developer.hashicorp.com/terraform/cli/commands/test](https://developer.hashicorp.com/terraform/cli/commands/test) |
| TFLint Documentation | [github.com/terraform-linters/tflint](https://github.com/terraform-linters/tflint) |
| AWS Provider Documentation | [registry.terraform.io/providers/hashicorp/aws](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) |
| Azure Provider Documentation | [registry.terraform.io/providers/hashicorp/azurerm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) |
| GCP Provider Documentation | [registry.terraform.io/providers/hashicorp/google](https://registry.terraform.io/providers/hashicorp/google/latest/docs) |

These resources provide authoritative guidance on Terraform features, syntax, and provider-specific configuration options.

---

## Scope Exceptions & Deviations from Standards

This section documents justified deviations from the standards defined in this document. When adopting this template, use this section to record exceptions specific to your organization, project, or deployment environment.

### How to Document Deviations

When a deviation from these standards is necessary, document it using the following format:

```markdown
#### [Short Description of Deviation]

- **Standard Affected:** [Link to or name of the standard being modified]
- **Reason:** [Business, technical, or organizational justification]
- **Scope:** [Which files, modules, or configurations are affected]
- **Approved By:** [Person or team who approved the deviation]
- **Date:** [YYYY-MM-DD]
- **Review Date:** [Optional: When this deviation should be reconsidered]
```

### Common Deviation Scenarios

The following are common scenarios where deviations may be justified:

- **Alternative Backend Workflows:** Using Terraform Cloud, Terraform Enterprise, Spacelift, or other orchestration tools instead of `backend.tf`. Document which backend sections do not apply.
- **Provider-Specific Requirements:** Organization policies that mandate specific provider configurations (e.g., required regions, mandatory tags beyond those listed).
- **Legacy Compatibility:** Maintaining compatibility with older Terraform versions or modules that cannot be immediately updated.
- **Organizational Naming Conventions:** Pre-existing naming conventions that conflict with this template but are required for consistency with other systems.
- **Security Policy Overrides:** Stricter security requirements that go beyond or differ from those specified here.

### Recorded Deviations

> **Note:** Replace the example below with actual deviations for your project, or remove this section if no deviations apply.

*No deviations recorded yet. When deviations are necessary, document them here using the format above.*

<!--
#### Example: Alternative Backend (Terraform Cloud)

- **Standard Affected:** [Remote Backend Configuration](#remote-backend-configuration)
- **Reason:** Organization uses Terraform Cloud for state management, which provides built-in state storage, locking, and encryption.
- **Scope:** All root modules in this repository
- **Approved By:** @platform-team
- **Date:** 2026-01-15
- **Review Date:** 2027-01-15

The following Remote Backend Configuration requirements are handled by Terraform Cloud and do not require explicit configuration:
- State encryption (automatic in Terraform Cloud)
- State locking (automatic in Terraform Cloud)
- DynamoDB lock table configuration (not applicable)
- S3/GCS/Azure Storage bucket configuration (not applicable)

The `cloud` block in `versions.tf` replaces the `backend` block for this repository.
-->

---

## Changelog

This section tracks significant changes to the Terraform instruction file.

| Version | Date | Changes |
| --- | --- | --- |
| 1.17.20260202.0 | 2026-02-02 | Added Upgrading Terraform Versions section with version upgrade checklist, pre-upgrade preparation steps, patch/minor and major upgrade procedures, lock file update guidance, CI/CD considerations, rollback procedures, and version manager recommendations |
| 1.16.20260202.0 | 2026-02-02 | Added Troubleshooting Common Issues section with guidance for 6 common Terraform errors: state lock acquisition, provider configuration not present, cycle detected, invalid for_each argument, unsupported Terraform version, and failed provider package queries |
| 1.15.20260202.0 | 2026-02-02 | Added Cross-Account and Service Account Patterns section with AWS assume_role, Azure skip_provider_registration and multi-subscription patterns, GCP impersonate_service_account, summary comparison table, and security considerations |
| 1.14.20260202.0 | 2026-02-02 | Added State Backup and Recovery section with backup strategies, manual backup procedures, common state problems and recovery guidance, and state versioning requirements |
| 1.13.20260202.0 | 2026-02-02 | Added Environment Separation Strategies section with guidance on workspaces vs directory-based environment separation |
| 1.12.20260202.0 | 2026-02-02 | Added Table of Contents entry for Code Authoring Guidelines section, updated AWS provider version reference in README template to `~> 6.0`, made version constraint examples in Provider Version Constraints table and glossary provider-agnostic |
| 1.12.20260201.0 | 2026-02-01 | Added `configuration_aliases` for module provider configuration, module-level `depends_on` documentation, sensitive output exposure in CLI security guidance, Terraform Cloud workspace tags pattern |
| 1.11.20260201.0 | 2026-02-01 | Added ephemeral values (1.10+), terraform_data resource (1.4+), updated security scanning tools (tfsec → trivy transition), added changelog |
| 1.10.20260201.0 | 2026-02-01 | Initial version targeting Terraform 1.10+ |

When updating this document, add a new row describing the changes made.

---

## Glossary

This glossary defines key Terraform terms used throughout this document.

| Term | Definition |
| --- | --- |
| **.tf.json extension** | An alternative JSON syntax for Terraform configuration, typically used for programmatically generated code. |
| **.tftpl extension** | The recommended file extension for Terraform template files used with `templatefile()`. |
| **backend** | The configuration that determines where Terraform stores its state file. Common backends include S3, Azure Storage, GCS, and Terraform Cloud. |
| **check block** | A Terraform construct (v1.5+) that runs continuous validation assertions on every `plan` and `apply`, producing warnings rather than errors when assertions fail. |
| **child module** | A module that is called by another module (the parent). Child modules are reusable components typically located in a `modules/` directory. Contrast with root module. |
| **configuration_aliases** | A list in the `required_providers` block that declares which provider aliases a module expects to receive from calling modules. Required when modules use provider aliases internally. |
| **data source** | A Terraform configuration element that reads information from external sources (cloud APIs, files, other Terraform state) without creating or managing resources. Data sources are declared with `data` blocks and provide read-only access to existing infrastructure or external data. |
| **force-unlock** | A Terraform CLI command (`terraform force-unlock <LOCK_ID>`) that manually releases a state lock. Used to recover from interrupted operations but dangerous if used while another operation is genuinely in progress. |
| **HCL** | HashiCorp Configuration Language. The primary language used to write Terraform configurations in `.tf` files. |
| **import block** | A declarative block (v1.5+) that brings existing infrastructure under Terraform management without using CLI commands, enabling version-controlled and reviewable imports. |
| **lifecycle block** | A nested block within resource or data source blocks that customizes resource behavior. Supports `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`, `precondition`, and `postcondition` arguments. |
| **locals** | Named expressions defined in a `locals` block that can be referenced throughout a module. Local values simplify configuration by assigning names to expressions, reducing repetition, and improving readability. Also called "local values." |
| **moved block** | A declarative block (v1.1+) that tells Terraform to treat a resource at a new address as the same resource that previously existed at a different address, enabling safe refactoring without destroying resources. |
| **partial backend configuration** | A pattern where static backend settings are committed to version control while dynamic values (bucket names, regions) are provided at runtime via `-backend-config` flags or files. |
| **pessimistic constraint operator** | The `~>` operator used in version constraints that allows only the rightmost version component to increment (for example, `~> X.0` allows versions `>= X.0.0` and `< (X+1).0.0`, i.e., all `X.*` but no `(X+1).0.0` or later). |
| **provider** | A plugin that Terraform uses to interact with cloud platforms, SaaS providers, and other APIs. Examples include `aws`, `azurerm`, and `google`. |
| **provider alias** | A named instance of a provider configuration that enables deploying resources to multiple regions, accounts, or with different settings within the same configuration. |
| **removed block** | A declarative block (v1.7+) that removes a resource from Terraform state without destroying the underlying infrastructure. |
| **resource** | A block that describes one or more infrastructure objects, such as virtual machines, storage buckets, or DNS records. |
| **reusable module** | A self-contained Terraform configuration designed to be called from root modules or other modules. Located in `modules/` directories and versioned for reuse. |
| **root module** | The top-level Terraform configuration directory where `terraform init`, `plan`, and `apply` are executed. Contains provider and backend configuration. Contrast with reusable (child) modules. |
| **state file** | A JSON file (typically named `terraform.tfstate`) that Terraform uses to map configuration to real-world resources and track metadata. |
| **state locking** | A mechanism that prevents concurrent Terraform operations on the same state file, avoiding race conditions and state corruption. |
| **state versioning** | A backup mechanism where the state storage backend (S3, GCS, Azure Storage) retains previous versions of state files, enabling recovery from corruption or accidental changes. |
| **templatefile() function** | A Terraform function that reads a template file and renders it with provided variables, commonly used for generating scripts, policies, or configuration files. |
| **terraform.lock.hcl** | The dependency lock file that records the exact provider versions and checksums used, ensuring reproducible installations across team members and CI systems. |
| **tfvars** | A file with the `.tfvars` extension that provides values for input variables. Commonly used for environment-specific configuration. |
| **variable validation** | Custom validation rules defined within variable blocks that enforce constraints on input values at plan time. |
| **workspace** | An isolated instance of state data within a single Terraform configuration. Workspaces enable multiple deployments of the same configuration with separate state files. The default workspace is named "default." Referenced via `terraform.workspace` in configuration. |
