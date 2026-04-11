# Guide: Writing Terraform Copilot Instructions

**Version:** 1.0.20260124.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-01-24
- **Scope:** This document provides comprehensive guidance for creating a `.github/instructions/terraform.instructions.md` file that matches the depth, structure, and quality of the PowerShell instructions file (~143KB). It covers best practices, recommendations, rationale, and implementation guidance for Terraform-specific Copilot instructions.
- **Related:** [Repository Copilot Instructions](../../.github/copilot-instructions.md)

## Purpose and Scope

This guide serves as a **reference document** for writing a comprehensive `terraform.instructions.md` file. The goal is to enable the creation of an instruction file that:

- Matches the **comprehensiveness and detail** of the existing PowerShell instructions file
- Follows the **established patterns and conventions** of this repository
- Provides **actionable, specific guidance** for Terraform development
- Integrates seamlessly with the **repository constitution** (`.github/copilot-instructions.md`)
- Includes **embedded testing guidance** for Terraform's native test framework

This guide is **prescriptive**—it uses RFC 2119 keywords (**MUST**, **SHOULD**, **MAY**, etc.) to indicate requirement levels for the resulting instruction file.

---

## Table of Contents

- [Document Structure Recommendations](#document-structure-recommendations)
- [YAML Front Matter Specification](#yaml-front-matter-specification)
- [Required Sections and Content](#required-sections-and-content)
- [Terraform Best Practices Research](#terraform-best-practices-research)
- [Coding Standards Recommendations](#coding-standards-recommendations)
- [Mode Distinctions: Scope Tags](#mode-distinctions-scope-tags)
- [Security Considerations](#security-considerations)
- [Testing with Terraform Test](#testing-with-terraform-test)
- [Documentation Standards](#documentation-standards)
- [Integration with Repository Constitution](#integration-with-repository-constitution)
- [Tooling and Pre-commit Configuration](#tooling-and-pre-commit-configuration)
- [Implementation Checklist](#implementation-checklist)

---

## Document Structure Recommendations

The `terraform.instructions.md` file **MUST** follow the structural pattern established by the PowerShell and Python instruction files. This section provides the recommended document skeleton.

### Required Document Skeleton

The instruction file **MUST** include the following sections in this order:

````markdown
---
applyTo: "**/*.tf,**/*.tfvars,**/*.tftest.hcl"
description: "Terraform coding standards: secure, modular, and well-documented infrastructure as code."
---

# Terraform Writing Style

**Version:** 1.0.YYYYMMDD.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** YYYY-MM-DD
- **Scope:** [Define scope]
- **Related:** [Repository Copilot Instructions](../copilot-instructions.md)

## Table of Contents

[Full navigation links to all major sections]

## Keywords

[RFC 2119 keyword definitions]

## Quick Reference Checklist

[Comprehensive checklist with scope tags and internal links]

## Executive Summary: Philosophy and Approach

[Overall Terraform philosophy for this repository]

## [Detailed Coding Standards Sections]

[Multiple deep-dive sections organized by topic]

## Testing with Terraform Test

[Embedded testing guidance - NOT just a reference]

## "Done" Definition for Terraform Changes

[What constitutes a complete change]
````

### Section Count and Depth

Based on the PowerShell instructions (~143KB, ~2800 lines), the Terraform instruction file **SHOULD** include:

- **At least 12-15 major sections** (H2 headers)
- **40-60 subsections** (H3 headers)
- **Comprehensive code examples** throughout
- **Tables for structured information** (naming conventions, options, comparisons)
- **A Quick Reference Checklist** with **40+ items** organized by category

---

## YAML Front Matter Specification

### Required YAML Front Matter

The instruction file **MUST** begin with YAML front matter specifying file patterns and description:

```yaml
---
applyTo: "**/*.tf,**/*.tfvars,**/*.tftest.hcl"
description: "Terraform coding standards: secure, modular, and well-documented infrastructure as code."
---
```

### Complete File Pattern Coverage

The `applyTo` field **SHOULD** cover all Terraform-related file types. Consider the following patterns:

| File Type | Pattern | Description |
| --- | --- | --- |
| Configuration files | `**/*.tf` | Main Terraform configuration files |
| Variable values | `**/*.tfvars` | Variable definition files |
| Auto-loaded variables | `**/*.auto.tfvars` | Auto-loaded variable files (subset of tfvars) |
| Test files | `**/*.tftest.hcl` | Native Terraform test files |
| JSON configuration | `**/*.tf.json` | JSON-format Terraform configuration |
| Template files | `**/*.tftpl` | Terraform template files |
| Backend config | `**/*.tfbackend` | Backend configuration files |

**Recommended comprehensive pattern:**

```yaml
applyTo: "**/*.tf,**/*.tfvars,**/*.tftest.hcl,**/*.tf.json,**/*.tftpl,**/*.tfbackend"
```

**Note:** The pattern syntax uses comma separation without spaces. Verify the pattern syntax is valid for the Copilot instruction file loader.

### Alternative: Multiple Instruction Files

For complex repositories, consider whether separate instruction files for different Terraform contexts are warranted:

| File | Pattern | Use Case |
| --- | --- | --- |
| `terraform.instructions.md` | `**/*.tf,**/*.tfvars` | Core Terraform configuration |
| `terraform-test.instructions.md` | `**/*.tftest.hcl` | Testing-specific guidance |
| `terraform-modules.instructions.md` | `modules/**/*.tf` | Module development |

**Recommendation:** Start with a single comprehensive file. Split only if the file becomes unwieldy (>200KB) or if distinct contexts require significantly different guidance.

---

## Required Sections and Content

This section details what **MUST** be included in each major section of the instruction file.

### 1. Title and Version

```text
# Terraform Writing Style

**Version:** 1.0.20260124.0
```

**Version format:** `Major.Minor.YYYYMMDD.Revision`

- **Major:** Increment for breaking changes to coding standards
- **Minor:** Increment for non-breaking additions/enhancements
- **YYYYMMDD:** Current date of modification
- **Revision:** Increment for same-day modifications

### 2. Metadata Section

**MUST** include:

```text
## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-01-24
- **Scope:** Defines Terraform coding standards for all `.tf`, `.tfvars`, `.tftest.hcl`, and related files in this repository. Covers style, formatting, naming conventions, module design, security, testing, and documentation requirements.
- **Related:** [Repository Copilot Instructions](../copilot-instructions.md)
```

### 3. Table of Contents

**MUST** include a comprehensive table of contents with anchor links to all major sections. Example:

```text
## Table of Contents

- [Keywords](#keywords)
- [Quick Reference Checklist](#quick-reference-checklist)
- [Executive Summary: Terraform Philosophy](#executive-summary-terraform-philosophy)
- [Formatting and Style](#formatting-and-style)
- [Naming Conventions](#naming-conventions)
- [File Organization](#file-organization)
- [Variable and Output Design](#variable-and-output-design)
- [Resource Configuration](#resource-configuration)
- [Module Design](#module-design)
- [State Management](#state-management)
- [Security Best Practices](#security-best-practices)
- [Provider Management](#provider-management)
- [Testing with Terraform Test](#testing-with-terraform-test)
- [Documentation Standards](#documentation-standards)
- ["Done" Definition for Terraform Changes](#done-definition-for-terraform-changes)
```

### 4. Keywords Section

**MUST** copy the RFC 2119 keyword definitions pattern from the PowerShell instructions:

```text
## Keywords

The key words "**MUST**", "**MUST NOT**", "**REQUIRED**", "**SHALL**", "**SHALL NOT**", "**SHOULD**", "**SHOULD NOT**", "**RECOMMENDED**", "**MAY**", and "**OPTIONAL**" in this document are to be interpreted as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

- **MUST** / **REQUIRED** / **SHALL** — Absolute requirement. Non-negotiable.
- **MUST NOT** / **SHALL NOT** — Absolute prohibition.
- **SHOULD** / **RECOMMENDED** — Strong recommendation. Valid reasons may exist to deviate, but implications must be understood.
- **SHOULD NOT** / **NOT RECOMMENDED** — Strong discouragement. Valid reasons may exist to do otherwise, but implications must be understood.
- **MAY** / **OPTIONAL** — Truly optional. Implementations can choose to include or omit.
```

### 5. Quick Reference Checklist

**MUST** include a comprehensive checklist following the PowerShell pattern. Each item **MUST** include:

1. **Scope tag** in bold brackets (e.g., `[All]`, `[Module]`, `[Root]`, `[Test]`)
2. **RFC 2119 keyword** in bold (e.g., **MUST**, **SHOULD**)
3. **Concise requirement statement**
4. **Link to detailed section** using `→ [Section Name](#anchor)`

Example structure:

```text
## Quick Reference Checklist

This checklist provides a quick reference for both human developers and LLMs (like GitHub Copilot) to follow the Terraform style guidelines. Each item includes a scope tag indicating applicability:

- **[All]** — Applies to all Terraform files
- **[Module]** — Applies when developing reusable modules
- **[Root]** — Applies to root configurations (deployments)
- **[Test]** — Applies to test files (`.tftest.hcl`)

### Formatting and Style

- **[All]** Code **MUST** pass `terraform fmt` without modifications → [Formatting Standards](#formatting-standards)
- **[All]** Code **MUST** use 2 spaces for indentation, never tabs → [Indentation Rules](#indentation-rules)
- **[All]** Files **MUST** use UTF-8 encoding → [File Encoding](#file-encoding)
- **[All]** Files **MUST** end with a single newline → [File Endings](#file-endings)
- **[All]** Lines **SHOULD NOT** exceed 120 characters → [Line Length](#line-length)

### Naming Conventions

- **[All]** Resources **MUST** use snake_case names → [Resource Naming](#resource-naming)
- **[All]** Variables **MUST** use snake_case with descriptive names → [Variable Naming](#variable-naming)
- **[All]** Outputs **MUST** use snake_case matching resource attribute patterns → [Output Naming](#output-naming)
- **[Module]** Module names **MUST** use hyphen-separated lowercase words → [Module Naming](#module-naming)
- **[All]** Data sources **MUST** be prefixed with purpose when multiple exist → [Data Source Naming](#data-source-naming)

[Continue for all categories...]
```

### 6. Executive Summary

**MUST** describe the overall Terraform philosophy and approach for this repository:

```text
## Executive Summary: Terraform Philosophy

This repository approaches Terraform as **infrastructure as code** with the same rigor applied to application code:

- **Deterministic and reproducible:** Infrastructure changes **MUST** produce predictable, repeatable results
- **Security-first:** Secrets **MUST NEVER** appear in code or state; least-privilege **MUST** be the default
- **Modular and reusable:** Common patterns **SHOULD** be extracted into versioned modules
- **Well-documented:** Every variable, output, and module **MUST** be documented
- **Testable:** Infrastructure **SHOULD** be validated with automated tests before deployment

The coding standards in this document enforce these principles through specific, actionable requirements.
```

---

## Terraform Best Practices Research

This section documents the Terraform best practices that **SHOULD** be incorporated into the instruction file. These are based on widely accepted HashiCorp conventions and industry standards as of Terraform 1.6+.

### HashiCorp Style Conventions

HashiCorp's official style conventions include:

1. **Indentation:** 2 spaces (not tabs)
2. **Alignment:** Use `terraform fmt` for consistent alignment
3. **Ordering:** Within resource blocks, follow `meta-arguments → arguments → nested blocks`
4. **Comments:** Use `#` for single-line comments; `/* */` for multi-line (rarely needed)

### File Organization Standards

Standard file organization for Terraform projects:

| File | Purpose | Required |
| --- | --- | --- |
| `main.tf` | Primary resource definitions | Yes |
| `variables.tf` | Input variable declarations | Yes |
| `outputs.tf` | Output value declarations | Yes |
| `providers.tf` | Provider configuration | Yes (root modules) |
| `versions.tf` or `terraform.tf` | Version constraints | Yes |
| `locals.tf` | Local value definitions | When needed |
| `data.tf` | Data source definitions | When needed |
| `backend.tf` | Backend configuration | Root modules only |

### Module Structure

Standard module directory structure:

```text
modules/
└── <module-name>/
    ├── main.tf           # Primary resources
    ├── variables.tf      # Input variables (REQUIRED)
    ├── outputs.tf        # Output values (REQUIRED)
    ├── versions.tf       # Version constraints (REQUIRED)
    ├── README.md         # Module documentation (REQUIRED)
    ├── examples/         # Usage examples (RECOMMENDED)
    │   └── basic/
    │       ├── main.tf
    │       └── outputs.tf
    └── tests/            # Test files (RECOMMENDED)
        └── basic.tftest.hcl
```

### Version Constraint Best Practices

Provider version constraints **SHOULD** follow these patterns:

| Pattern | Example | Use Case |
| --- | --- | --- |
| Pessimistic constraint | `~> 5.0` | Allow minor version updates only |
| Exact version | `= 5.31.0` | Strict reproducibility required |
| Range constraint | `>= 5.0, < 6.0` | Explicit major version bounds |

**Recommended approach:**

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### Lock File Management

The `.terraform.lock.hcl` file:

- **MUST** be committed to version control
- **SHOULD** be updated explicitly using `terraform providers lock`
- **MUST** be updated when provider versions change
- **SHOULD** include hashes for all platforms in CI (`-platform=linux_amd64 -platform=darwin_amd64`)

---

## Coding Standards Recommendations

This section provides detailed recommendations for each coding standard area.

### Formatting Standards

#### terraform fmt Compliance

```text
### Formatting Standards

#### terraform fmt Compliance

All Terraform code **MUST** pass `terraform fmt` without modifications. This is non-negotiable.

**Verification command:**

\`\`\`bash
terraform fmt -check -recursive
\`\`\`

**Auto-format command:**

\`\`\`bash
terraform fmt -recursive
\`\`\`

**Pre-commit integration:**

\`\`\`yaml
- repo: https://github.com/antonbabenko/pre-commit-terraform
  rev: v1.105.0
  hooks:
    - id: terraform_fmt
\`\`\`
```

#### Indentation Rules

```text
#### Indentation Rules

- Code **MUST** use 2 spaces for indentation
- Tabs **MUST NOT** be used
- Nested blocks **MUST** maintain consistent indentation

**Compliant:**

\`\`\`hcl
resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name        = var.instance_name
    Environment = var.environment
  }
}
\`\`\`
```

### Naming Conventions

The instruction file **MUST** include comprehensive naming convention tables similar to PowerShell's approved verbs.

#### Resource Naming

```text
### Resource Naming Conventions

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
```

#### Variable Naming

```text
### Variable Naming Conventions

Variables **MUST** use `snake_case` and **MUST** be descriptive.

| Category | Pattern | Example |
| --- | --- | --- |
| Simple values | `<noun>` or `<adjective>_<noun>` | `instance_type`, `environment` |
| Lists/Sets | Plural nouns | `subnet_ids`, `security_group_ids` |
| Maps | `<noun>_map` or descriptive | `tags`, `instance_settings` |
| Booleans | `enable_*`, `is_*`, `has_*` | `enable_monitoring`, `is_public` |
| Resource references | `<resource>_id` or `<resource>_arn` | `vpc_id`, `role_arn` |

**Compliant variable names:**

\`\`\`hcl
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
\`\`\`
```

#### Output Naming

```text
### Output Naming Conventions

Outputs **MUST** use `snake_case` and **SHOULD** follow the pattern of the attribute being exposed.

| Output Type | Pattern | Example |
| --- | --- | --- |
| Resource ID | `<resource>_id` | `instance_id`, `vpc_id` |
| Resource ARN | `<resource>_arn` | `role_arn`, `bucket_arn` |
| Resource name | `<resource>_name` | `bucket_name`, `cluster_name` |
| Endpoints/URLs | `<resource>_endpoint` | `rds_endpoint`, `api_endpoint` |
| Collections | Plural form | `instance_ids`, `subnet_ids` |
```

### Variable and Output Design

#### Variable Documentation Requirements

```text
### Variable Documentation Requirements

Every variable **MUST** include:

1. **description** (REQUIRED) — Human-readable explanation
2. **type** (REQUIRED) — Explicit type constraint
3. **default** (CONDITIONAL) — Required for optional variables
4. **validation** (RECOMMENDED) — For constrained inputs
5. **sensitive** (CONDITIONAL) — Required for secrets

**Minimal compliant variable:**

\`\`\`hcl
variable "environment" {
  description = "Deployment environment. Valid values: dev, staging, prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
\`\`\`

**Variable with default:**

\`\`\`hcl
variable "instance_type" {
  description = "EC2 instance type for the application server."
  type        = string
  default     = "t3.micro"
}
\`\`\`

**Sensitive variable:**

\`\`\`hcl
variable "database_password" {
  description = "Password for the RDS database. Must be provided via environment variable or tfvars."
  type        = string
  sensitive   = true
}
\`\`\`
```

#### Output Documentation Requirements

```text
### Output Documentation Requirements

Every output **MUST** include a description. Sensitive outputs **MUST** be marked.

\`\`\`hcl
output "instance_id" {
  description = "The ID of the created EC2 instance."
  value       = aws_instance.main.id
}

output "instance_private_ip" {
  description = "The private IP address of the EC2 instance."
  value       = aws_instance.main.private_ip
  sensitive   = true  # If this should be protected
}
\`\`\`
```

### Resource Configuration

#### Meta-Argument Ordering

```text
### Meta-Argument Ordering

Within resource blocks, arguments **MUST** follow this order:

1. **Meta-arguments first:** `count`, `for_each`, `provider`, `depends_on`, `lifecycle`
2. **Required arguments:** Arguments without defaults
3. **Optional arguments:** Arguments with defaults
4. **Nested blocks last:** Dynamic blocks, inline blocks

**Compliant example:**

\`\`\`hcl
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
\`\`\`
```

#### Resource Tagging Standards

```text
### Resource Tagging Standards

#### Required Tags

All taggable resources **MUST** include these tags:

| Tag | Description | Example |
| --- | --- | --- |
| `Name` | Human-readable resource name | `prod-web-server-1` |
| `Environment` | Deployment environment | `prod`, `staging`, `dev` |
| `Project` | Project or application name | `my-application` |
| `ManagedBy` | Management method | `terraform` |
| `Owner` | Team or individual owner | `platform-team` |

#### Default Tags Configuration

Root modules **SHOULD** use provider-level default tags:

\`\`\`hcl
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
\`\`\`

#### Local Tags Pattern

Use locals for computed or merged tags:

\`\`\`hcl
locals {
  common_tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}
\`\`\`
```

### Module Design

```text
### Module Design Principles

#### Reusability Guidelines

Modules **SHOULD** be designed for reuse:

- **Single responsibility:** Each module **SHOULD** manage one logical component
- **Minimal coupling:** Modules **SHOULD** have minimal dependencies on each other
- **Explicit interface:** All inputs and outputs **MUST** be documented
- **Sensible defaults:** Optional variables **SHOULD** have reasonable defaults
- **Version constraints:** Modules **MUST** specify required Terraform and provider versions

#### Module Interface Design

**Inputs:**

- Variable names **MUST** be consistent across modules (e.g., always `environment`, not sometimes `env`)
- Required variables **SHOULD** be minimized to essential values
- Complex inputs **SHOULD** use object types with documented structure

**Outputs:**

- Expose only values needed by calling modules
- Use consistent naming patterns across modules
- Document output types and formats

#### Module Versioning

For published modules:

- Use semantic versioning (e.g., `v1.2.3`)
- Document breaking changes in CHANGELOG
- Pin module versions in root configurations

\`\`\`hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  # ...
}
\`\`\`
```

### State Management

```text
### State Management

#### Backend Configuration

Root modules **MUST** configure a remote backend for team environments:

\`\`\`hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "environments/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
\`\`\`

**Backend requirements:**

- State files **MUST** be encrypted at rest
- State access **MUST** be controlled via IAM
- State locking **MUST** be enabled to prevent concurrent modifications
- State files **MUST NOT** be committed to version control

#### State File Organization

Organize state files by environment and component:

\`\`\`text
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
\`\`\`

#### Workspace Usage

Workspaces **MAY** be used for environment separation in simple cases:

\`\`\`bash
terraform workspace select prod
terraform apply
\`\`\`

**Caution:** For complex environments, separate state files per environment are often clearer than workspaces.
```

---

## Mode Distinctions: Scope Tags

The instruction file **SHOULD** define distinct scope tags to indicate when rules apply. Based on Terraform's structure, the following tags are recommended:

### Recommended Scope Tags

| Tag | Applies To | Description |
| --- | --- | --- |
| `[All]` | All Terraform files | Universal rules applicable everywhere |
| `[Module]` | Reusable modules | Rules for developing modules in `modules/` |
| `[Root]` | Root configurations | Rules for deployment configurations |
| `[Test]` | Test files | Rules for `.tftest.hcl` files |

### Tag Usage Examples

```text
### Quick Reference Checklist

#### File Organization

- **[All]** Every Terraform directory **MUST** have a `versions.tf` file → [Version Constraints](#version-constraints)
- **[Module]** Modules **MUST** include a `README.md` → [Module Documentation](#module-documentation)
- **[Root]** Root modules **MUST** configure a remote backend → [Backend Configuration](#backend-configuration)
- **[Test]** Test files **MUST** use the `.tftest.hcl` extension → [Test File Naming](#test-file-naming)

#### Security

- **[All]** Secrets **MUST NOT** appear in `.tf` files → [Secret Management](#secret-management)
- **[Root]** State backends **MUST** enable encryption → [State Security](#state-security)
- **[Module]** Sensitive outputs **MUST** be marked with `sensitive = true` → [Sensitive Data](#sensitive-data)
```

### Rationale for Tag Selection

- **[All]** vs specific tags: Use `[All]` for universal formatting, naming, and documentation rules that apply regardless of context.
- **[Module]** vs **[Root]**: Modules have different requirements (e.g., no backend config) than root deployments (e.g., must have backend config).
- **[Test]**: Test files have unique syntax and patterns that warrant separate guidance.

---

## Security Considerations

This section outlines the security content that **MUST** be included in the instruction file.

### Secrets and Sensitive Variable Handling

```text
## Security Best Practices

### Secret Management

Secrets **MUST NEVER** appear in Terraform code or version control.

#### Prohibited Patterns

The following patterns are **PROHIBITED**:

\`\`\`hcl
# NEVER DO THIS
variable "db_password" {
  default = "SuperSecretPassword123!"  # PROHIBITED
}

resource "aws_db_instance" "main" {
  password = "hardcoded-password"  # PROHIBITED
}
\`\`\`

#### Approved Secret Patterns

**Pattern 1: Environment Variables**

\`\`\`hcl
variable "db_password" {
  description = "Database password. Set via TF_VAR_db_password environment variable."
  type        = string
  sensitive   = true
}
\`\`\`

\`\`\`bash
export TF_VAR_db_password="$(aws secretsmanager get-secret-value ...)"
terraform apply
\`\`\`

**Pattern 2: Secret Manager Integration**

\`\`\`hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/database/password"
}

resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}
\`\`\`

**Pattern 3: HashiCorp Vault**

\`\`\`hcl
data "vault_generic_secret" "db_creds" {
  path = "secret/data/database"
}

resource "aws_db_instance" "main" {
  username = data.vault_generic_secret.db_creds.data["username"]
  password = data.vault_generic_secret.db_creds.data["password"]
}
\`\`\`

### Sensitive Variable Marking

Variables containing sensitive data **MUST** be marked:

\`\`\`hcl
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
\`\`\`
```

### State File Security

```text
### State File Security

State files contain sensitive data and **MUST** be protected.

#### Requirements

1. **Encryption at rest:** State backends **MUST** enable encryption
2. **Access control:** State files **MUST** be accessible only to authorized users/roles
3. **No local state in production:** Local state files **MUST NOT** be used for production
4. **State locking:** Backends **MUST** support state locking

#### S3 Backend Security Configuration

\`\`\`hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true                    # REQUIRED
    dynamodb_table = "terraform-state-lock"  # REQUIRED for locking
    # Use IAM role or credentials from environment
  }
}
\`\`\`

#### State Bucket Policy Example

\`\`\`json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::my-terraform-state",
        "arn:aws:s3:::my-terraform-state/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
\`\`\`
```

### Least-Privilege Resource Policies

```text
### Least-Privilege Principles

IAM policies and resource permissions **MUST** follow least-privilege:

#### IAM Policy Guidelines

- Grant only required permissions
- Use resource-level restrictions when possible
- Avoid wildcard actions (`*`) except when truly needed
- Use conditions to further restrict access

\`\`\`hcl
# GOOD: Specific permissions
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

# BAD: Overly permissive
resource "aws_iam_policy" "bad_example" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:*"]      # TOO BROAD
      Resource = ["*"]          # TOO BROAD
    }]
  })
}
\`\`\`
```

### Security Scanning Integration

```text
### Security Scanning

Security scanning tools **SHOULD** be integrated into the development workflow.

#### Recommended Tools

| Tool | Purpose | Integration |
| --- | --- | --- |
| `tfsec` | Static security analysis | Pre-commit, CI |
| `checkov` | Policy-as-code scanning | Pre-commit, CI |
| `terrascan` | Security and compliance | CI |
| `trivy` | Misconfiguration scanning | CI |

#### Pre-commit Integration Example

\`\`\`yaml
- repo: https://github.com/antonbabenko/pre-commit-terraform
  rev: v1.105.0
  hooks:
    - id: terraform_tfsec
    - id: terraform_checkov
\`\`\`

**Note:** Security scanning is **RECOMMENDED** but specific tool selection depends on project requirements. The instruction file **SHOULD** document which tools are expected for the repository.
```

---

## Testing with Terraform Test

Following the PowerShell pattern, testing guidance **MUST** be embedded directly in the instruction file. This section provides the content that **SHOULD** be included.

### Overview

```text
## Testing with Terraform Test

Terraform's native test framework (introduced in Terraform 1.6) provides a way to validate configurations without external testing tools. This section documents testing conventions that integrate with the coding standards in this guide.

> **Note:** Terraform tests require Terraform 1.6.0 or later. For older Terraform versions, consider Terratest or other external testing frameworks.
```

### Test File Naming and Location

```text
### Test File Naming and Location

Test files **MUST** follow consistent naming conventions:

- **File extension:** Test files **MUST** use `.tftest.hcl` extension
- **Location:** Test files **SHOULD** be placed in a `tests/` directory within the module
- **Naming:** Test files **SHOULD** be named descriptively based on what they test

**Module with tests:**

\`\`\`text
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
\`\`\`

**Alternative: Tests alongside configuration:**

\`\`\`text
modules/
└── vpc/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── vpc.tftest.hcl
    └── vpc_validation.tftest.hcl
\`\`\`
```

### Test File Structure

```text
### Test File Structure

Terraform test files use HCL syntax with specific blocks.

#### Basic Test Structure

\`\`\`hcl
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
\`\`\`

#### Test Block Reference

| Block | Purpose | Required |
| --- | --- | --- |
| `variables {}` | Set input variable values for tests | Optional |
| `provider {}` | Configure provider for tests (e.g., mock) | Optional |
| `run "name" {}` | Define a test scenario | Required (at least one) |
| `assert {}` | Define a test assertion within a run | Required (at least one per run) |
| `expect_failures` | Expect specific resources/outputs to fail | Optional |
```

### Test Patterns

```text
### Test Patterns

#### Arrange-Act-Assert in Terraform Tests

Tests **SHOULD** follow a logical structure similar to AAA:

\`\`\`hcl
# tests/instance.tftest.hcl

# Arrange: Set up test inputs
variables {
  instance_type = "t3.micro"
  environment   = "test"
}

# Act & Assert: Run terraform and check results
run "instance_has_correct_type" {
  command = plan

  # Assert
  assert {
    condition     = aws_instance.main.instance_type == "t3.micro"
    error_message = "Instance type should be t3.micro"
  }
}

run "instance_has_required_tags" {
  command = plan

  assert {
    condition     = aws_instance.main.tags["Environment"] == "test"
    error_message = "Instance must have Environment tag"
  }

  assert {
    condition     = aws_instance.main.tags["ManagedBy"] == "terraform"
    error_message = "Instance must have ManagedBy tag"
  }
}
\`\`\`

#### Testing Variable Validation

\`\`\`hcl
# tests/validation.tftest.hcl

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

  # No expect_failures - should succeed
  assert {
    condition     = var.environment == "prod"
    error_message = "Environment should be prod"
  }
}
\`\`\`

#### Testing Outputs

\`\`\`hcl
# tests/outputs.tftest.hcl

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
\`\`\`
```

### Mock Providers

```text
### Mock Providers

For unit testing without real infrastructure, use mock providers:

\`\`\`hcl
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
\`\`\`
```

### Unit vs Integration Tests

```text
### Unit vs Integration Tests

#### Unit Tests (command = plan)

- Use `command = plan` (default)
- Do NOT create real resources
- Fast execution
- Test configuration logic, not cloud provider behavior

\`\`\`hcl
run "unit_test_example" {
  command = plan  # Explicit, though it's the default

  assert {
    condition     = aws_instance.main.instance_type == var.instance_type
    error_message = "Instance type mismatch"
  }
}
\`\`\`

#### Integration Tests (command = apply)

- Use `command = apply`
- Create and destroy real resources
- Slower execution
- Test actual infrastructure behavior
- Require valid provider credentials

\`\`\`hcl
run "integration_test_example" {
  command = apply  # Creates real resources

  assert {
    condition     = aws_instance.main.id != ""
    error_message = "Instance should be created"
  }
}
\`\`\`

**Best Practice:** Run unit tests (`plan`) frequently during development. Run integration tests (`apply`) in CI or before releases.
```

### Running Tests

```text
### Running Tests

#### Basic Test Execution

\`\`\`bash
# Run all tests in current directory
terraform test

# Run tests with verbose output
terraform test -verbose

# Run specific test file
terraform test -filter=tests/basic.tftest.hcl
\`\`\`

#### CI Integration Example

\`\`\`yaml
# .github/workflows/terraform-ci.yml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.0"

      - name: Terraform Init
        run: terraform init

      - name: Terraform Test
        run: terraform test -verbose
\`\`\`
```

### What to Test

```text
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
```

---

## Documentation Standards

This section defines the documentation requirements for the instruction file.

### README Requirements for Modules

```text
### Module Documentation

Every module **MUST** include a `README.md` with:

1. **Description** — What the module does
2. **Usage example** — Minimal working example
3. **Requirements** — Terraform and provider versions
4. **Inputs** — All variables with descriptions
5. **Outputs** — All outputs with descriptions

#### README Template

\`\`\`markdown
# Module Name

Brief description of what this module creates.

## Usage

\`\`\`hcl
module "example" {
  source = "./modules/example"

  required_variable = "value"
}
\`\`\`

## Requirements

| Name | Version |
| --- | --- |
| terraform | >= 1.6.0 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | --- |
| required_variable | Description here | `string` | n/a | yes |
| optional_variable | Description here | `string` | `"default"` | no |

## Outputs

| Name | Description |
| --- | --- |
| output_name | Description of output |
\`\`\`

**Automation:** Consider using `terraform-docs` to generate input/output tables automatically.
```

### Inline Comment Conventions

```text
### Inline Comments

Comments **SHOULD** explain "why," not "what."

#### Single-Line Comments

Use `#` for single-line comments:

\`\`\`hcl
# Enable encryption to meet compliance requirements (SOC2)
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  # ...
}
\`\`\`

#### Block Comments

Use `/* */` sparingly for multi-line explanations:

\`\`\`hcl
/*
 * This security group allows inbound traffic from the corporate VPN.
 * CIDR ranges are managed by the network team and should not be
 * modified without their approval.
 */
resource "aws_security_group" "vpn_access" {
  # ...
}
\`\`\`

#### TODO Comments

Use standardized TODO format:

\`\`\`hcl
# TODO(username): Migrate to new VPC module after v2.0 release
\`\`\`
```

---

## Integration with Repository Constitution

The instruction file **MUST** integrate with the repository's `copilot-instructions.md`.

### Referencing the Constitution

```text
## Related

- **[Repository Copilot Instructions](../copilot-instructions.md)** — Repo-wide constitution. If any instruction in this file conflicts with the constitution, **the constitution wins**.
```

### Pre-commit Discipline

The instruction file **MUST** emphasize pre-commit discipline consistent with the constitution:

```text
### Pre-commit Discipline for Terraform

**⚠️ ALWAYS run pre-commit checks before committing Terraform code.**

Pre-commit hooks for Terraform **SHOULD** include:

1. `terraform fmt` — Format check
2. `terraform validate` — Syntax validation
3. `tflint` — Linting
4. Security scanning (optional but recommended)

**Workflow:**

1. Make Terraform changes
2. Run `terraform fmt -recursive`
3. Run `terraform validate`
4. Run pre-commit hooks: `pre-commit run --all-files`
5. Review and commit ALL auto-fixes as part of your change
6. Push to GitHub

**CI is a safety net, not a substitute for local checks.**
```

### Updating the Language-Specific Instructions Table

When the `terraform.instructions.md` file is created, the table in `copilot-instructions.md` **MUST** be updated:

```text
| Language | Instruction File | Applies To |
| --- | --- | --- |
| Markdown/Docs | `.github/instructions/docs.instructions.md` | `**/*.md` |
| PowerShell | `.github/instructions/powershell.instructions.md` | `**/*.ps1` |
| Python | `.github/instructions/python.instructions.md` | `**/*.py` |
| Terraform | `.github/instructions/terraform.instructions.md` | `**/*.tf, **/*.tfvars, **/*.tftest.hcl` |
```

The Linting Configurations table **SHOULD** also be updated if Terraform-specific linting configurations are added:

```text
| Tool | Configuration File | Purpose |
| --- | --- | --- |
| PSScriptAnalyzer | `.github/linting/PSScriptAnalyzerSettings.psd1` | PowerShell formatting/linting (OTBS style) |
| markdownlint | `.markdownlint.jsonc` | Markdown linting |
| tflint | `.tflint.hcl` | Terraform linting |
```

The Testing Tools table **SHOULD** be updated:

```text
| Language | Framework | Configuration | Test Location |
| --- | --- | --- | --- |
| Python | pytest | `pyproject.toml` | `tests/` |
| PowerShell | Pester 5.x | Inline in CI | `tests/PowerShell/` |
| Terraform | Terraform Test | Built-in (1.6+) | `modules/*/tests/` |
```

---

## Tooling and Pre-commit Configuration

### Recommended Pre-commit Hooks

```text
### Terraform Pre-commit Hooks

The following pre-commit configuration is **RECOMMENDED** for Terraform:

\`\`\`yaml
# .pre-commit-config.yaml (Terraform section)
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.105.0  # Pinned version – update periodically
    hooks:
      # Required hooks
      - id: terraform_fmt
      - id: terraform_validate

      # Recommended hooks
      - id: terraform_tflint
        args:
          - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl

      # Optional security scanning
      - id: terraform_tfsec
      - id: terraform_checkov
        args:
          - --args=--quiet
          - --args=--compact
\`\`\`
```

### TFLint Configuration

```text
### TFLint Configuration

A `.tflint.hcl` configuration file **SHOULD** be created at the repository root:

\`\`\`hcl
# .tflint.hcl

config {
  format = "compact"
  plugin_dir = "~/.tflint.d/plugins"

  call_module_type    = "local"
  force               = false
  disabled_by_default = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS-specific rules (if using AWS)
plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Rule overrides
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}
\`\`\`
```

### CI Workflow Example

```text
### Terraform CI Workflow

A GitHub Actions workflow for Terraform **SHOULD** include:

\`\`\`yaml
# .github/workflows/terraform-ci.yml
name: Terraform CI

on:
  push:
    paths:
      - '**/*.tf'
      - '**/*.tfvars'
      - '**/*.tftest.hcl'
      - '.tflint.hcl'
  pull_request:
    paths:
      - '**/*.tf'
      - '**/*.tfvars'
      - '**/*.tftest.hcl'
      - '.tflint.hcl'

jobs:
  validate:
    name: Validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.0"

      - name: Terraform Format Check
        run: terraform fmt -check -recursive -diff

      - name: Terraform Init
        run: terraform init -backend=false

      - name: Terraform Validate
        run: terraform validate

  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: terraform-linters/setup-tflint@v4

      - name: Init TFLint
        run: tflint --init

      - name: Run TFLint
        run: tflint --recursive

  test:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.0"

      - name: Terraform Init
        run: terraform init

      - name: Terraform Test
        run: terraform test -verbose

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.3
        with:
          soft_fail: true  # Set to false to fail on findings
\`\`\`
```

---

## Implementation Checklist

Use this checklist when creating the `terraform.instructions.md` file:

### Document Structure

- [ ] YAML front matter with `applyTo` and `description`
- [ ] Title with version number (`1.0.YYYYMMDD.0` format)
- [ ] Metadata section (Status, Owner, Last Updated, Scope, Related)
- [ ] Comprehensive Table of Contents with anchor links
- [ ] Keywords section (RFC 2119 definitions)
- [ ] Quick Reference Checklist (40+ items with scope tags and links)
- [ ] Executive Summary describing Terraform philosophy

### Coding Standards Coverage

- [ ] Formatting standards (`terraform fmt`, indentation)
- [ ] Naming conventions (resources, variables, outputs, modules)
- [ ] File organization patterns (standard files, when to split)
- [ ] Variable documentation requirements (description, type, validation)
- [ ] Output documentation requirements
- [ ] Resource configuration (meta-argument ordering, tagging)
- [ ] Module design principles
- [ ] State management guidance
- [ ] Provider management and version constraints

### Security Content

- [ ] Secret management (prohibited patterns, approved patterns)
- [ ] Sensitive variable marking
- [ ] State file security (encryption, access control, locking)
- [ ] Least-privilege resource policies
- [ ] Security scanning recommendations

### Testing Content

- [ ] Test file naming and location
- [ ] Test file structure (blocks, syntax)
- [ ] Test patterns (AAA, validation, outputs)
- [ ] Mock providers
- [ ] Unit vs integration tests
- [ ] Running tests (commands, CI integration)
- [ ] What to test guidance

### Documentation Standards

- [ ] Module README requirements
- [ ] Inline comment conventions
- [ ] Example usage documentation

### Integration

- [ ] Reference to repository constitution
- [ ] Pre-commit discipline guidance
- [ ] "Done" definition section
- [ ] Instructions for updating `copilot-instructions.md` tables

### Quality Checks

- [ ] All checklist items link to detailed sections
- [ ] Comprehensive code examples throughout
- [ ] Tables for structured information
- [ ] RFC 2119 keywords used consistently
- [ ] No contradictions with repository constitution
- [ ] Document is comprehensive (~100KB+ target for depth matching PowerShell)

---

## Recommended Next Steps

1. **Create the instruction file:** Use this guide to write `.github/instructions/terraform.instructions.md`

2. **Add tooling configuration:**
   - Create `.tflint.hcl` at repository root
   - Update `.pre-commit-config.yaml` with Terraform hooks
   - Create `.github/workflows/terraform-ci.yml`

3. **Update the repository constitution:**
   - Add Terraform to the Language-Specific Instructions table
   - Add TFLint to the Linting Configurations table
   - Add Terraform Test to the Testing Tools table

4. **Validate the instruction file:**
   - Verify all anchor links work
   - Ensure no contradictions with `copilot-instructions.md`
   - Test that the applyTo pattern works correctly

5. **Iterate based on usage:**
   - Gather feedback from Copilot-generated Terraform code
   - Refine rules that produce undesirable outputs
   - Add examples for common patterns

---

## References

This guide is based on widely accepted Terraform conventions and best practices:

- HashiCorp Terraform Style Conventions
- HashiCorp Terraform Best Practices
- Terraform Module Registry conventions
- terraform-docs documentation standards
- pre-commit-terraform hook collection
- Community patterns from terraform-aws-modules and similar projects

**Note:** Specific URLs and external links are intentionally omitted as they may change. The patterns documented here represent stable, long-standing conventions in the Terraform ecosystem as of Terraform 1.6+.
