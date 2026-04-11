# Terraform Unit Testing Implementation Guide

**Version:** 1.0.20260124.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-01-24
- **Scope:** This document provides comprehensive guidance for implementing Terraform unit testing in CI for the `franklesniak/copilot-repo-template` repository. It serves two purposes: (1) CI/Infrastructure Implementation Guide for setting up Terraform testing in GitHub Actions, and (2) Content Specification for what testing guidance should be embedded in `terraform.instructions.md`. This is a **guidance-only** document—it does not modify workflows or configurations directly.
- **Related:** [Repository Copilot Instructions](../../.github/copilot-instructions.md), [Terraform Instructions](../../.github/instructions/terraform.instructions.md), [Terraform Linting Guide](./TERRAFORM_LINTING_GUIDE.md)

---

## Table of Contents

- [Introduction](#introduction)
- [Part 1: Testing Framework Analysis](#part-1-testing-framework-analysis)
- [Part 2: Native Terraform Test Framework Deep Dive](#part-2-native-terraform-test-framework-deep-dive)
- [Part 3: Test Organization Best Practices](#part-3-test-organization-best-practices)
- [Part 4: CI Integration Recommendations](#part-4-ci-integration-recommendations)
- [Part 5: Test Writing Guidelines](#part-5-test-writing-guidelines)
- [Part 6: Content Specification for terraform.instructions.md](#part-6-content-specification-for-terraforminstructionsmd)
- [Part 7: Integration with Repository Patterns](#part-7-integration-with-repository-patterns)
- [Part 8: Advanced Topics](#part-8-advanced-topics)
- [Assumptions and Validation Notes](#assumptions-and-validation-notes)
- [Summary of Recommended Implementation Steps](#summary-of-recommended-implementation-steps)

---

## Introduction

This guide provides comprehensive recommendations for implementing Terraform unit testing in CI for this repository. The goal is to establish a consistent, reliable, and maintainable Terraform testing workflow that:

- **Validates configuration logic** before deployment
- **Catches errors early** in the development cycle
- **Ensures module interfaces** work as designed
- **Verifies variable validation rules** function correctly
- **Integrates seamlessly** with the existing CI infrastructure

All recommendations in this guide follow the patterns established in this repository's existing Python and PowerShell CI workflows. This guide uses RFC 2119 keywords (**MUST**, **SHOULD**, **MAY**, etc.) to indicate requirement levels.

### Dual Purpose of This Document

This document serves **TWO critical purposes**:

1. **CI/Infrastructure Implementation Guide:** Detailed guidance on setting up Terraform testing in GitHub Actions workflows, test directory structure, CI configuration, and operational patterns.

2. **Content Specification for terraform.instructions.md:** Explicit recommendations for what testing guidance should be **embedded directly in the Terraform Copilot instructions file**, following the pattern established by the PowerShell instructions file's "Testing with Pester" section.

The distinction between these purposes is highlighted throughout the document where applicable.

---

## Part 1: Testing Framework Analysis

This section provides a comprehensive comparison of Terraform testing approaches to inform framework selection.

### Native Terraform Testing (`terraform test`)

**Official Documentation:** [Terraform Test Command](https://developer.hashicorp.com/terraform/cli/commands/test)

#### How It Works

The native Terraform test framework, introduced in Terraform 1.6.0, allows you to write tests in HCL using `.tftest.hcl` files. Tests are executed using the `terraform test` command, which:

1. Discovers all `.tftest.hcl` files in the current directory and `tests/` subdirectory
2. Runs each test file's `run` blocks in sequence
3. Evaluates `assert` blocks to verify expected conditions
4. Reports pass/fail status with detailed error messages

#### .tftest.hcl File Structure

Test files use HCL syntax with specialized blocks:

```hcl
# tests/basic.tftest.hcl

# Global variables for all run blocks
variables {
  environment = "test"
  instance_type = "t3.micro"
}

# Optional: Mock provider configuration
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }
}

# Test scenario 1
run "validates_instance_type" {
  command = plan

  assert {
    condition     = aws_instance.main.instance_type == "t3.micro"
    error_message = "Instance type mismatch"
  }
}

# Test scenario 2 with overridden variables
run "rejects_invalid_environment" {
  command = plan

  variables {
    environment = "invalid"
  }

  expect_failures = [
    var.environment
  ]
}
```

#### Capabilities and Limitations

| Capability | Description |
| --- | --- |
| Unit testing (`plan`) | Validates configuration without creating resources |
| Integration testing (`apply`) | Creates and destroys real resources |
| Mock providers | Simulates provider behavior for isolated testing |
| Variable validation testing | Tests custom validation rules via `expect_failures` |
| Output verification | Validates output values in assertions |
| Module testing | Tests modules in isolation or as compositions |

| Limitation | Description |
| --- | --- |
| Terraform 1.6.0+ required | Not available in older Terraform versions |
| Limited assertion operators | No built-in regex or complex matchers |
| Sequential execution | Test files run sequentially, not in parallel |
| Mock provider limitations | Not all provider behaviors can be mocked |

#### Pros

- **Native integration:** Built into Terraform CLI, no additional tools required
- **HCL-based:** Uses familiar Terraform syntax for test definitions
- **Mock providers:** Enables true unit testing without cloud access
- **Fast unit tests:** `command = plan` tests execute quickly
- **No language barrier:** No need to learn Go, Ruby, or Python

#### Cons

- **Version requirement:** Requires Terraform 1.6.0 or later
- **Limited matchers:** Fewer assertion options than full testing frameworks
- **Newer framework:** Less community adoption and examples than Terratest
- **Mock limitations:** Complex provider interactions may not be mockable

#### When to Use

Use native Terraform testing as the **primary testing approach** for:

- Variable validation rule testing
- Output value verification
- Configuration logic validation
- Module interface testing
- Any unit testing that doesn't require real infrastructure

---

### Terratest (Go-based Integration Testing)

**Official Documentation:** [Terratest on GitHub](https://github.com/gruntwork-io/terratest)

#### How It Works

Terratest is a Go library that provides helper functions for testing Terraform code. Tests are written in Go and executed using the standard Go testing framework:

```go
// test/vpc_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestVpcCreation(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../modules/vpc",
        Vars: map[string]interface{}{
            "cidr_block": "10.0.0.0/16",
        },
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    vpcId := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcId)
}
```

#### Capabilities

- **Real infrastructure testing:** Creates and destroys actual cloud resources
- **Rich assertions:** Full power of Go testing and assertion libraries
- **HTTP/SSH testing:** Built-in helpers for testing deployed applications
- **Retry logic:** Handles eventual consistency with configurable retries
- **Parallel testing:** Go test parallelization support

#### Pros

- **Comprehensive testing:** Tests actual infrastructure behavior
- **Mature ecosystem:** Large community and extensive documentation
- **Powerful assertions:** Full Go testing capabilities
- **Cross-platform:** Tests AWS, Azure, GCP, Kubernetes, and more

#### Cons

- **Requires Go knowledge:** Learning curve for non-Go developers
- **Slower execution:** Creates real resources, incurring time and cost
- **Complex setup:** Requires Go installation and module management
- **Cost implications:** Real resource creation generates cloud costs

#### When to Use

Use Terratest for:

- End-to-end integration testing of complete infrastructure
- Testing actual cloud provider behavior
- Verifying deployed application functionality
- Complex multi-resource dependency testing

---

### Kitchen-Terraform (Ruby-based Testing)

**Official Documentation:** [Kitchen-Terraform on GitHub](https://github.com/newcontext-oss/kitchen-terraform)

#### How It Works

Kitchen-Terraform integrates Terraform with Test Kitchen, a Ruby-based testing framework. Tests are defined using InSpec profiles:

```ruby
# test/integration/default/controls/vpc_test.rb
control 'vpc-1.0' do
  impact 1.0
  title 'VPC Configuration'
  desc 'Verify VPC is created correctly'

  describe aws_vpc(vpc_id: input('vpc_id')) do
    it { should exist }
    its('cidr_block') { should eq '10.0.0.0/16' }
  end
end
```

#### Pros

- **Compliance-focused:** InSpec profiles align with security/compliance requirements
- **Readable tests:** Human-readable test definitions
- **Platform maturity:** Test Kitchen is a mature testing framework

#### Cons

- **Ruby dependency:** Requires Ruby runtime and gem management
- **Additional tooling:** Requires Test Kitchen and InSpec setup
- **Smaller community:** Less Terraform-specific adoption than Terratest
- **Complex configuration:** Multiple configuration files required

#### When to Use

Use Kitchen-Terraform for:

- Compliance and security testing scenarios
- Organizations already using Chef/InSpec
- Teams with Ruby expertise

---

### pytest-terraform (Python-based Testing)

**Official Documentation:** [pytest-terraform on GitHub](https://github.com/cloud-custodian/pytest-terraform)

#### How It Works

pytest-terraform provides pytest fixtures and helpers for testing Terraform:

```python
# test_vpc.py
import pytest

@pytest.mark.terraform('modules/vpc')
def test_vpc_creation(terraform):
    terraform.init()
    terraform.apply()
    outputs = terraform.output()
    assert outputs['vpc_id'] is not None
```

#### Pros

- **Python ecosystem:** Integrates with pytest and Python tooling
- **Familiar syntax:** Uses standard pytest patterns
- **Existing infrastructure:** Leverages Python CI/CD pipelines

#### Cons

- **Less mature:** Smaller community than Terratest
- **Limited features:** Fewer Terraform-specific helpers
- **Still requires apply:** Tests create real resources

#### When to Use

Use pytest-terraform for:

- Python-centric organizations
- Integration with existing pytest suites
- Teams with strong Python expertise

---

### Recommendation Summary

Based on the analysis above, this guide recommends the following testing approach:

| Priority | Framework | Use Case |
| --- | --- | --- |
| **Primary** | Native Terraform Test (`terraform test`) | Unit testing, variable validation, output verification, module interfaces |
| **Secondary** | Terratest | Integration testing requiring real infrastructure when native tests are insufficient |
| **Not Recommended** | Kitchen-Terraform, pytest-terraform | Unless organization has specific Ruby/Python requirements |

**Rationale for Native Terraform Test as Primary:**

1. **No additional tooling:** Uses Terraform CLI already required for development
2. **HCL familiarity:** Developers write tests in the same language as configurations
3. **Fast execution:** Unit tests with `command = plan` are quick and cost-free
4. **Mock providers:** Enables true isolation for unit testing
5. **Built-in integration:** Aligns with HashiCorp's product direction
6. **Lower barrier to entry:** No Go or Ruby knowledge required

**When to Opt into Terratest:**

- Tests require verification of actual cloud provider behavior
- Complex multi-resource dependencies need end-to-end validation
- HTTP/SSH connectivity testing is required for deployed applications
- Native mocking is insufficient for the testing scenario

---

## Part 2: Native Terraform Test Framework Deep Dive

Since native Terraform testing is the recommended primary approach, this section provides detailed coverage of its features and patterns.

### .tftest.hcl File Structure and Syntax

#### File Format Overview

Terraform test files use HCL syntax with specialized blocks. The file extension **MUST** be `.tftest.hcl`.

#### Complete Block Reference

| Block | Purpose | Cardinality |
| --- | --- | --- |
| `variables {}` | Set global variable values for all run blocks | 0..1 per file |
| `provider "name" {}` | Configure provider for tests | 0..n per file |
| `mock_provider "name" {}` | Mock a provider for unit testing | 0..n per file |
| `run "name" {}` | Define a test scenario | 1..n per file (at least one required) |
| `assert {}` | Define an assertion within a run block | 1..n per run (at least one required) |
| `expect_failures` | List of resources/variables expected to fail | 0..1 per run |

#### Complete Syntax Reference

```hcl
# tests/comprehensive.tftest.hcl

# Global variables (optional) - Apply to all run blocks
variables {
  environment   = "test"
  instance_type = "t3.micro"
  enable_logging = true
}

# Mock provider (optional) - For unit testing without real infrastructure
mock_provider "aws" {
  # Mock data source responses
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  # Mock resource behavior
  mock_resource "aws_instance" {
    defaults = {
      id = "i-mock12345"
      arn = "arn:aws:ec2:us-east-1:123456789012:instance/i-mock12345"
    }
  }
}

# Run block - Defines a test scenario
run "test_name_describing_scenario" {
  # Command type: plan (default) or apply
  command = plan

  # Override variables for this specific run (optional)
  variables {
    instance_type = "t3.small"
  }

  # Module reference (optional) - Test a specific module
  module {
    source = "./modules/example"
  }

  # Assertion blocks (at least one required)
  assert {
    condition     = aws_instance.main.instance_type == "t3.small"
    error_message = "Instance type should be t3.small"
  }

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Expected 3 private subnets"
  }
}

# Negative testing with expect_failures
run "rejects_invalid_input" {
  command = plan

  variables {
    environment = "invalid"  # This should fail validation
  }

  # List of objects expected to fail
  expect_failures = [
    var.environment
  ]
}
```

### Test File Organization Patterns

#### Directory Structure

Test files **SHOULD** be placed in a `tests/` directory within each module:

```text
modules/
└── vpc/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── versions.tf
    ├── README.md
    └── tests/
        ├── unit.tftest.hcl           # Unit tests with mock providers
        ├── validation.tftest.hcl     # Variable validation tests
        └── integration.tftest.hcl    # Integration tests (apply)
```

#### Alternative: Tests Alongside Configuration

For simple modules, tests **MAY** be placed alongside configuration files:

```text
modules/
└── simple-module/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── simple-module.tftest.hcl      # Primary test file
    └── simple-module-edge.tftest.hcl # Edge case tests
```

#### Naming Conventions

| Pattern | Purpose | Example |
| --- | --- | --- |
| `unit.tftest.hcl` | Unit tests with mocks | `tests/unit.tftest.hcl` |
| `validation.tftest.hcl` | Variable validation tests | `tests/validation.tftest.hcl` |
| `integration.tftest.hcl` | Apply-based tests | `tests/integration.tftest.hcl` |
| `<feature>.tftest.hcl` | Feature-specific tests | `tests/networking.tftest.hcl` |
| `<module>.tftest.hcl` | Module-named tests | `vpc.tftest.hcl` |

### Writing Unit Tests vs Integration Tests

#### Unit Tests (command = plan)

Unit tests use `command = plan` (the default) and **SHOULD**:

- Use mock providers to avoid real infrastructure
- Execute quickly (seconds, not minutes)
- Test configuration logic, not provider behavior
- Validate variable values and computed attributes
- Verify resource configuration before creation

```hcl
# tests/unit.tftest.hcl

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

run "validates_tag_configuration" {
  command = plan  # Explicit but optional (plan is default)

  assert {
    condition     = aws_instance.main.tags["Environment"] == var.environment
    error_message = "Environment tag not set correctly"
  }
}
```

#### Integration Tests (command = apply)

Integration tests use `command = apply` and **SHOULD**:

- Create real resources for full validation
- Be run sparingly due to time and cost
- Include proper cleanup (automatic with `terraform test`)
- Be separated from unit tests for selective execution
- Require valid provider credentials

```hcl
# tests/integration.tftest.hcl

run "creates_vpc_successfully" {
  command = apply  # Creates real resources

  assert {
    condition     = aws_vpc.main.id != ""
    error_message = "VPC should be created"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true
    error_message = "DNS hostnames should be enabled"
  }
}
```

#### Separation Recommendation

| Test Type | Command | Speed | Cost | When to Run |
| --- | --- | --- | --- | --- |
| Unit | `plan` | Fast (seconds) | Free | Every commit, PR |
| Integration | `apply` | Slow (minutes) | Paid | Pre-release, scheduled |

### Mock Providers and Mock Data

#### Mock Provider Configuration

Mock providers replace real provider interactions for unit testing:

```hcl
mock_provider "aws" {
  # Mock data sources
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-12345678"
      name = "mock-ami"
    }
  }

  # Mock resource computed attributes
  mock_resource "aws_instance" {
    defaults = {
      id = "i-mock12345"
      arn = "arn:aws:ec2:us-east-1:123456789012:instance/i-mock12345"
      private_ip = "10.0.1.100"
      public_ip = "52.1.2.3"
    }
  }

  mock_resource "aws_vpc" {
    defaults = {
      id = "vpc-mock12345"
      arn = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock12345"
      default_network_acl_id = "acl-mock12345"
    }
  }
}
```

#### Override Mock Values Per Run

```hcl
run "tests_with_custom_mock" {
  command = plan

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["us-west-2a", "us-west-2b"]
    }
  }

  override_resource {
    target = aws_instance.main
    values = {
      private_ip = "10.0.2.50"
    }
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Should create 2 subnets for 2 AZs"
  }
}
```

### Test Assertions and Expected Outcomes

#### Assertion Block Structure

```hcl
assert {
  condition     = <boolean_expression>
  error_message = "<descriptive message when condition is false>"
}
```

#### Common Assertion Patterns

```hcl
# Equality check
assert {
  condition     = aws_instance.main.instance_type == var.instance_type
  error_message = "Instance type mismatch"
}

# Not empty check
assert {
  condition     = aws_vpc.main.id != ""
  error_message = "VPC ID should not be empty"
}

# Length check
assert {
  condition     = length(aws_subnet.private) == 3
  error_message = "Expected 3 private subnets"
}

# Contains check
assert {
  condition     = contains(keys(aws_instance.main.tags), "Environment")
  error_message = "Instance must have Environment tag"
}

# Regex match (using can() and regex())
assert {
  condition     = can(regex("^vpc-[a-z0-9]+$", aws_vpc.main.id))
  error_message = "VPC ID format is invalid"
}

# Null check
assert {
  condition     = aws_instance.main.public_ip != null
  error_message = "Instance should have a public IP"
}

# Boolean attribute
assert {
  condition     = aws_vpc.main.enable_dns_hostnames == true
  error_message = "DNS hostnames should be enabled"
}

# Output verification
assert {
  condition     = output.vpc_id != "" && output.vpc_id != null
  error_message = "vpc_id output must not be empty"
}
```

### Variables and Variable Files in Tests

#### Global Variables Block

Set variables that apply to all run blocks:

```hcl
variables {
  environment   = "test"
  project_name  = "testing"
  instance_type = "t3.micro"
}
```

#### Per-Run Variable Overrides

Override specific variables for individual test scenarios:

```hcl
run "tests_production_config" {
  variables {
    environment = "prod"
    instance_type = "t3.large"
  }

  assert {
    condition     = aws_instance.main.instance_type == "t3.large"
    error_message = "Production should use t3.large"
  }
}
```

### Run Blocks and Their Configuration

#### Run Block Reference

```hcl
run "descriptive_test_name" {
  # Command type (optional, defaults to plan)
  command = plan  # or apply

  # Override variables (optional)
  variables {
    key = "value"
  }

  # Test a specific module (optional)
  module {
    source = "./modules/submodule"
  }

  # Override mock data/resources (optional)
  override_data {
    target = data.aws_ami.latest
    values = { id = "ami-custom" }
  }

  # Assertions (at least one required)
  assert {
    condition     = <expression>
    error_message = "Message"
  }

  # Expected failures for negative testing (optional)
  expect_failures = [
    var.environment,
    aws_instance.web
  ]
}
```

#### expect_failures for Negative Testing

Test that invalid inputs are properly rejected:

```hcl
run "rejects_invalid_environment" {
  command = plan

  variables {
    environment = "invalid"  # Not in allowed list
  }

  expect_failures = [
    var.environment  # Expects variable validation to fail
  ]
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    vpc_cidr = "not-a-cidr"
  }

  expect_failures = [
    var.vpc_cidr
  ]
}
```

---

## Part 3: Test Organization Best Practices

### Directory Structure Recommendations

#### Recommended Module Test Structure

```text
repository/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── README.md
│   │   └── tests/
│   │       ├── unit.tftest.hcl
│   │       ├── validation.tftest.hcl
│   │       └── integration.tftest.hcl
│   ├── ec2-instance/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── README.md
│   │   └── tests/
│   │       ├── unit.tftest.hcl
│   │       └── validation.tftest.hcl
│   └── s3-bucket/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       ├── README.md
│       └── tests/
│           └── basic.tftest.hcl
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── tests/
│   │       └── environment.tftest.hcl
│   └── prod/
│       ├── main.tf
│       └── variables.tf
└── templates/
    └── terraform/
        └── Example.tftest.hcl  # Recommended template (to be created)
```

> **Note:** The `templates/terraform/Example.tftest.hcl` file is a recommended template that **SHOULD** be created following the pattern established by `templates/powershell/Example.Tests.ps1`. See [Part 7: Integration with Repository Patterns](#part-7-integration-with-repository-patterns) for the recommended template content.

### Naming Conventions for Test Files

| Convention | Pattern | Description |
| --- | --- | --- |
| Functional | `unit.tftest.hcl`, `integration.tftest.hcl` | Grouped by test type |
| Feature | `networking.tftest.hcl`, `security.tftest.hcl` | Grouped by feature area |
| Scenario | `basic.tftest.hcl`, `complex.tftest.hcl` | Grouped by complexity |
| Module-named | `vpc.tftest.hcl` | Named after the module |

**Recommendation:** Use functional naming (`unit`, `validation`, `integration`) for consistency across modules.

### Separating Unit Tests from Integration Tests

Unit and integration tests **SHOULD** be in separate files:

| File | Purpose | CI Behavior |
| --- | --- | --- |
| `tests/unit.tftest.hcl` | Fast plan-based tests with mocks | Run on every commit |
| `tests/validation.tftest.hcl` | Variable validation testing | Run on every commit |
| `tests/integration.tftest.hcl` | Apply-based tests with real resources | Run on release/scheduled |

**Filter by File:**

```bash
# Run only unit tests
terraform test -filter=tests/unit.tftest.hcl

# Run only validation tests
terraform test -filter=tests/validation.tftest.hcl
```

### Module Testing vs Root Module Testing

#### Testing Modules in Isolation

Each module **SHOULD** have its own test suite:

```hcl
# modules/vpc/tests/unit.tftest.hcl

variables {
  cidr_block = "10.0.0.0/16"
  environment = "test"
}

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["us-east-1a", "us-east-1b"] }
  }
}

run "creates_vpc_with_specified_cidr" {
  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR mismatch"
  }
}
```

#### Testing Root Module Configurations

Root modules (environments) **MAY** have tests verifying composition:

```hcl
# environments/dev/tests/environment.tftest.hcl

run "dev_environment_uses_small_instances" {
  assert {
    condition     = module.compute.instance_type == "t3.micro"
    error_message = "Dev should use t3.micro instances"
  }
}
```

### Test Fixtures and Helper Modules

#### Creating Reusable Test Fixtures

For complex test scenarios, create fixture modules:

```text
modules/
└── vpc/
    └── tests/
        ├── unit.tftest.hcl
        └── fixtures/
            └── mock-vpc/
                ├── main.tf
                └── outputs.tf
```

```hcl
# tests/fixtures/mock-vpc/main.tf
output "vpc_id" {
  value = "vpc-fixture12345"
}

output "subnet_ids" {
  value = ["subnet-1", "subnet-2", "subnet-3"]
}
```

---

## Part 4: CI Integration Recommendations

### GitHub Actions Workflow Design

Following the patterns established in the existing `terraform-ci.yml` workflow, test execution **SHOULD** be integrated as a dedicated job.

#### Workflow Structure

The existing `terraform-ci.yml` already includes a `test` job with appropriate design. Key elements:

```yaml
test:
  name: Test
  needs: validate
  runs-on: ubuntu-latest

  steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: "1.6.0"

    - name: Check for test files
      id: check-tests
      run: |
        if find . -name '*.tftest.hcl' | grep -q .; then
          echo "has_tests=true" >> $GITHUB_OUTPUT
        else
          echo "has_tests=false" >> $GITHUB_OUTPUT
        fi

    - name: Run Terraform Tests
      if: steps.check-tests.outputs.has_tests == 'true'
      run: terraform test -verbose
```

### Job Organization and Dependencies

The recommended job dependency chain:

```text
format → validate → lint (parallel with test) → security (optional)
                  ↘                           ↗
                    ----→ test ---------------
```

| Job | Depends On | Purpose |
| --- | --- | --- |
| format | none | Check formatting first |
| validate | format | Validate after formatting passes |
| lint | validate | Lint valid configurations |
| test | validate | Test valid configurations |
| security | validate | Security scan (optional, parallel with lint) |

### Matrix Testing Across Terraform Versions

For modules supporting multiple Terraform versions:

```yaml
test:
  name: Test (Terraform ${{ matrix.terraform }})
  runs-on: ubuntu-latest
  strategy:
    matrix:
      terraform: ['1.6.0', '1.7.0', '1.8.0']
    fail-fast: false

  steps:
    - uses: actions/checkout@v4

    - uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ matrix.terraform }}

    - name: Run Tests
      run: terraform test -verbose
```

**Recommendation:** For this template repository, pin to a single version (1.6.0) for simplicity. Users can add matrix testing as needed.

### Provider Authentication for Integration Tests

#### Mock-First Approach (Recommended for Unit Tests)

Use mock providers to avoid authentication requirements:

```hcl
# tests/unit.tftest.hcl
mock_provider "aws" {
  # No credentials needed
}
```

#### Real Provider Authentication (Integration Tests)

When integration tests are required:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1

- name: Run Integration Tests
  run: terraform test -filter=tests/integration.tftest.hcl
```

**Security Recommendations:**

- Use OIDC authentication (role-to-assume) over static credentials
- Limit IAM role permissions to minimum required for tests
- Use separate AWS accounts for testing
- Never store credentials in code or logs

### Secrets and Environment Variable Handling

```yaml
env:
  TF_VAR_environment: "ci-test"
  TF_IN_AUTOMATION: "true"

steps:
  - name: Run Tests with Variables
    env:
      TF_VAR_api_key: ${{ secrets.TEST_API_KEY }}
    run: terraform test -verbose
```

**Best Practices:**

- Use `TF_VAR_` prefix for Terraform variables
- Set `TF_IN_AUTOMATION=true` to suppress interactive prompts
- Use GitHub Secrets for sensitive values
- Never echo or log secret values

### Test Result Reporting

```yaml
- name: Run Terraform Tests
  id: test
  run: |
    terraform test -verbose 2>&1 | tee test-output.txt
    echo "exit_code=${PIPESTATUS[0]}" >> $GITHUB_OUTPUT

- name: Upload Test Results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: terraform-test-results
    path: test-output.txt
```

---

## Part 5: Test Writing Guidelines

### What to Test in Terraform

| Category | What to Test | Example |
| --- | --- | --- |
| **Variable validation** | Custom validation rules work correctly | Invalid environment rejected |
| **Computed values** | Locals and expressions compute correctly | CIDR calculations, name generation |
| **Resource configuration** | Resources have expected attributes | Instance type, tags, security settings |
| **Output values** | Outputs contain expected values | VPC ID not empty, ARN format valid |
| **Conditional logic** | Count/for_each behave correctly | Zero instances when disabled |
| **Module interfaces** | Modules accept inputs and produce outputs | Module composition works |
| **Edge cases** | Boundary conditions handled | Empty lists, null values |
| **Negative scenarios** | Invalid inputs are rejected | Bad CIDR, invalid region |

### What NOT to Test

- **Cloud provider behavior:** Don't test if AWS actually creates an EC2 instance
- **Terraform core functionality:** Don't test if `count` works
- **External service availability:** Don't test if the AWS API is up
- **Provider bugs:** Report to provider maintainers instead

### Test Isolation and Idempotency

Tests **MUST** be isolated and idempotent:

```hcl
# Good: Uses unique names via variables or locals
variables {
  name_prefix = "test"
}

run "creates_unique_resources" {
  variables {
    # Note: Using timestamp() can affect test reproducibility.
    # For CI, consider using a static prefix or run-specific identifier.
    name_prefix = "ci-test-unique"
  }

  # ...
}
```

**Principles:**

- Each test should be independent of others
- Tests should produce same results when run multiple times
- Use unique resource names to avoid conflicts
- Clean up resources after tests (automatic with `terraform test`)

### Handling Stateful Resources in Tests

For unit tests, use mocks to avoid state issues:

```hcl
mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      id = "mock-bucket"
      arn = "arn:aws:s3:::mock-bucket"
    }
  }
}
```

For integration tests, rely on `terraform test` automatic cleanup:

- Resources are destroyed after each test file
- Use `command = apply` only when necessary
- Design tests to minimize resource creation

### Cleanup and Resource Destruction

`terraform test` automatically handles cleanup:

1. After each `run` block with `command = apply`, resources are preserved
2. After all runs in a file complete, resources are destroyed
3. If a test fails, cleanup still occurs

**For manual cleanup:**

```bash
# If automatic cleanup fails
cd modules/vpc
terraform destroy -auto-approve
```

### Testing Modules Independently

Each module **SHOULD** have tests that validate its interface:

```hcl
# modules/ec2-instance/tests/unit.tftest.hcl

variables {
  instance_type = "t3.micro"
  ami_id        = "ami-12345678"
  subnet_id     = "subnet-mock"
}

mock_provider "aws" {}

run "uses_specified_instance_type" {
  assert {
    condition     = aws_instance.main.instance_type == var.instance_type
    error_message = "Instance type should match input variable"
  }
}

run "accepts_custom_tags" {
  variables {
    additional_tags = {
      Team = "Engineering"
    }
  }

  assert {
    condition     = aws_instance.main.tags["Team"] == "Engineering"
    error_message = "Custom tags should be applied"
  }
}
```

---

## Part 6: Content Specification for terraform.instructions.md

This section specifies what testing guidance should be **embedded directly in the Terraform Copilot instructions file**, following the pattern established by the PowerShell instructions file's "Testing with Pester" section.

### Section Structure for "Testing with Terraform Test"

The current `terraform.instructions.md` already includes a "Testing with Terraform Test" section (starting at line 1356). This section provides the specification for its content.

#### Recommended Table of Contents Entry

```markdown
- [Testing with Terraform Test](#testing-with-terraform-test)
```

#### Recommended Subsections

The "Testing with Terraform Test" section **SHOULD** include these subsections (most already exist):

1. Test File Naming
2. Test File Location
3. Test Structure
4. Test Assertions
5. Testing Variable Validation
6. Testing Outputs
7. Mock Providers
8. Unit Tests
9. Integration Tests
10. Running Tests
11. What to Test

### Quick Reference Checklist Entries for Testing

The following entries **SHOULD** appear in the Quick Reference Checklist under a "### Testing" heading. These entries are currently present in the terraform.instructions.md:

```markdown
### Testing

- **[Test]** Test files **MUST** use `.tftest.hcl` extension → [Test File Naming](#test-file-naming)
- **[Test]** Test files **SHOULD** be in a `tests/` directory → [Test File Location](#test-file-location)
- **[Test]** Tests **MUST** include at least one `run` block → [Test Structure](#test-structure)
- **[Test]** Each `run` block **MUST** include at least one `assert` → [Test Assertions](#test-assertions)
- **[Test]** Variable validation **SHOULD** be tested → [Testing Variable Validation](#testing-variable-validation)
- **[Test]** Unit tests **SHOULD** use `command = plan` → [Unit Tests](#unit-tests)
- **[Test]** Integration tests **MAY** use `command = apply` → [Integration Tests](#integration-tests)
```

#### Additional Checklist Entries to Consider

```markdown
- **[Module]** Modules **SHOULD** include corresponding Terraform tests → [Module Tests](#module-tests)
- **[Test]** Mock providers **SHOULD** be used for unit tests → [Mock Providers](#mock-providers)
- **[Test]** Negative test cases **SHOULD** use `expect_failures` → [Testing Variable Validation](#testing-variable-validation)
```

### RFC 2119 Keyword Usage

The testing section **SHOULD** use RFC 2119 keywords consistently:

| Keyword | Testing Requirement |
| --- | --- |
| **MUST** | Test file extension (`.tftest.hcl`), run block requirement, assert requirement |
| **SHOULD** | Test file location, unit test command, mock provider usage, variable validation testing |
| **MAY** | Integration test usage, test organization alternatives |

### Detailed Section Content Specification

The "Testing with Terraform Test" section **SHOULD** include the following content (adapting the patterns from the PowerShell testing section):

#### 1. Introduction Paragraph

```markdown
Terraform's native test framework (introduced in Terraform 1.6) provides a way to validate configurations without external testing tools. This section documents testing conventions that integrate with the coding standards in this guide.

> **Note:** Terraform tests require Terraform 1.6.0 or later. For older Terraform versions, consider Terratest or other external testing frameworks.
```

#### 2. Test File Naming

Document the required file extension and naming patterns.

#### 3. Test File Location

Include directory structure diagrams showing both preferred and alternative locations.

#### 4. Test Structure

Provide the HCL block reference table and basic test structure example.

#### 5. Test Assertions

Show assertion patterns with examples for common scenarios.

#### 6. Testing Variable Validation

Demonstrate `expect_failures` pattern for negative testing.

#### 7. Mock Providers

Show how to configure mock providers for unit testing.

#### 8. Unit Tests vs Integration Tests

Clearly distinguish command types and when to use each.

#### 9. Running Tests

Provide CLI commands for local and CI execution.

#### 10. What to Test

Include a table of what to test and what not to test.

### Example Content Structure

The following demonstrates the style and structure that **SHOULD** be followed (already present in terraform.instructions.md):

```markdown
## Testing with Terraform Test

Terraform's native test framework (introduced in Terraform 1.6) provides a way to validate configurations without external testing tools.

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
    └── tests/
        └── basic.tftest.hcl
```

[Continue with remaining sections...]

---

## Part 7: Integration with Repository Patterns

### Updating the Testing Tools Table in copilot-instructions.md

The `copilot-instructions.md` file includes a Testing Tools table that **SHOULD** include Terraform. The current table already includes Terraform:

```markdown
| Language | Framework | Configuration | Test Location |
| --- | --- | --- | --- |
| Python | pytest | `pyproject.toml` (`[tool.pytest.ini_options]`) | `tests/` |
| PowerShell | Pester 5.x | Inline in `.github/workflows/powershell-ci.yml` | `tests/PowerShell/` |
| Terraform | Terraform Test | Built-in (Terraform 1.6+) | `modules/*/tests/` |
```

**Verification:** The Terraform entry is already present in the current `copilot-instructions.md`.

### Template Test File Creation

A template test file **SHOULD** be created at `templates/terraform/Example.tftest.hcl` following the pattern established by `templates/powershell/Example.Tests.ps1`.

#### What the Template Should Demonstrate

1. **File header comments:** Purpose, prerequisites, usage instructions
2. **Global variables block:** Setting test variables
3. **Mock provider configuration:** AWS mock with data sources and resources
4. **Basic run block:** Simple assertion example
5. **Variable validation testing:** Using `expect_failures`
6. **Output verification:** Testing output values
7. **Multiple assertions:** Showing assertion patterns
8. **Unit vs integration examples:** Both `plan` and `apply` commands

#### Recommended Template Structure

> **Implementation Note:** This template **SHOULD** be created at `templates/terraform/Example.tftest.hcl` as part of the Terraform testing implementation. The `templates/terraform/` directory does not currently exist and would need to be created.

```hcl
# Example.tftest.hcl
#
# TEMPLATE FILE: Copy this file to modules/<module>/tests/ and customize.
#
# This file demonstrates Terraform test patterns including:
#   - Global variables for test configuration
#   - Mock providers for unit testing
#   - Basic assertions with condition/error_message
#   - Variable validation testing with expect_failures
#   - Output verification
#   - Unit tests (command = plan) vs integration tests (command = apply)
#
# Prerequisites:
#   - Terraform 1.6.0 or later
#
# Usage (from module directory):
#   terraform test
#   terraform test -verbose
#   terraform test -filter=tests/Example.tftest.hcl
#
# For complete Terraform test documentation:
# https://developer.hashicorp.com/terraform/cli/commands/test

# ==============================================================================
# Global Variables
# ==============================================================================
# Variables defined here apply to all run blocks unless overridden.

variables {
  environment   = "test"
  instance_type = "t3.micro"
  # Add your module's required variables here
}

# ==============================================================================
# Mock Provider Configuration
# ==============================================================================
# Mock providers enable unit testing without real cloud credentials.

mock_provider "aws" {
  # Mock data sources
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  # Mock resource computed attributes
  mock_resource "aws_instance" {
    defaults = {
      id         = "i-mock12345"
      arn        = "arn:aws:ec2:us-east-1:123456789012:instance/i-mock12345"
      private_ip = "10.0.1.100"
    }
  }
}

# ==============================================================================
# Unit Tests (command = plan)
# ==============================================================================
# Unit tests validate configuration logic without creating resources.

run "validates_instance_type" {
  command = plan

  assert {
    condition     = aws_instance.main.instance_type == var.instance_type
    error_message = "Instance type should match input variable"
  }
}

run "applies_environment_tag" {
  command = plan

  assert {
    condition     = aws_instance.main.tags["Environment"] == var.environment
    error_message = "Environment tag should be set"
  }
}

# ==============================================================================
# Variable Validation Tests
# ==============================================================================
# Test that invalid inputs are properly rejected.

run "rejects_invalid_environment" {
  command = plan

  variables {
    environment = "invalid"  # Should fail validation
  }

  expect_failures = [
    var.environment
  ]
}

# ==============================================================================
# Output Verification
# ==============================================================================
# Verify outputs contain expected values.

run "outputs_instance_id" {
  command = plan

  assert {
    condition     = output.instance_id != null
    error_message = "instance_id output must not be null"
  }
}

# ==============================================================================
# Integration Tests (command = apply)
# ==============================================================================
# Integration tests create real resources. Use sparingly.
# Uncomment when you have valid provider credentials.
#
# run "creates_instance_successfully" {
#   command = apply
#
#   assert {
#     condition     = aws_instance.main.id != ""
#     error_message = "Instance should be created"
#   }
# }
```

### Pre-commit Hooks for Test Validation

Consider adding test-related pre-commit hooks:

```yaml
# .pre-commit-config.yaml additions (recommendations only)
- repo: https://github.com/antonbabenko/pre-commit-terraform
  rev: v1.105.0
  hooks:
    # Existing hooks...
    - id: terraform_validate
      # Validates test files as part of validation
```

**Note:** `terraform fmt` already handles `.tftest.hcl` files. No additional hooks are required for test file formatting.

### README.md Updates

The repository README **SHOULD** include a testing section:

```markdown
## Testing

### Terraform

Terraform modules include unit tests using the native Terraform test framework:

```bash
# Run all tests
terraform test -verbose

# Run specific test file
terraform test -filter=tests/unit.tftest.hcl
```

Tests are located in `modules/*/tests/` directories.

---

## Part 8: Advanced Topics

### Testing with Multiple Providers

#### Multi-Provider Test Configuration

```hcl
# tests/multi-provider.tftest.hcl

mock_provider "aws" {
  alias = "primary"
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
}

mock_provider "aws" {
  alias = "secondary"
  mock_data "aws_region" {
    defaults = { name = "us-west-2" }
  }
}

run "uses_correct_regions" {
  assert {
    condition     = aws_vpc.primary.tags["Region"] == "us-east-1"
    error_message = "Primary VPC should be in us-east-1"
  }

  assert {
    condition     = aws_vpc.secondary.tags["Region"] == "us-west-2"
    error_message = "Secondary VPC should be in us-west-2"
  }
}
```

### Testing Provider-Specific Resources

#### AWS-Specific Testing Considerations

```hcl
mock_provider "aws" {
  # Mock common AWS data sources
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
}
```

#### Azure-Specific Testing Considerations

```hcl
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}
```

#### GCP-Specific Testing Considerations

```hcl
mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      project_id = "mock-project-id"
      number     = "123456789012"
    }
  }
}
```

#### Generic Patterns

When writing provider-agnostic tests:

1. Mock all data sources your configuration uses
2. Provide realistic default values for computed attributes
3. Test resource configurations, not provider behavior
4. Use variables for provider-specific values (regions, zones, etc.)

### Continuous Testing Strategies

#### When to Run Full vs Partial Test Suites

| Trigger | Test Scope | Rationale |
| --- | --- | --- |
| PR/Commit | Unit tests only | Fast feedback, no cost |
| Merge to main | Unit + validation | Ensure quality gate |
| Pre-release | Full suite including integration | Comprehensive validation |
| Scheduled (weekly) | Full integration | Catch drift, provider changes |

#### Scheduled Testing for Drift Detection

```yaml
# Scheduled workflow for comprehensive testing
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform test  # Full suite
```

### Test Coverage Considerations

#### What "Coverage" Means for Terraform

Unlike code coverage for programming languages, Terraform test coverage refers to:

- **Configuration coverage:** Percentage of resources/modules with tests
- **Validation coverage:** Percentage of validation rules tested
- **Output coverage:** Percentage of outputs verified
- **Scenario coverage:** Percentage of use cases tested

#### Measuring Test Effectiveness

| Metric | How to Measure |
| --- | --- |
| Resource coverage | Count resources with tests / total resources |
| Validation coverage | Count validation rules tested / total validation rules |
| Output coverage | Count outputs verified / total outputs |
| Branch coverage | Count conditional paths tested / total conditional paths |

#### Critical Paths to Cover

Tests **SHOULD** prioritize:

1. **Security configurations:** Encryption, IAM policies, network security
2. **Variable validation rules:** All custom validations should be tested
3. **Complex expressions:** Locals with calculations or conditionals
4. **Module interfaces:** All inputs and outputs
5. **Edge cases:** Empty lists, null values, boundary conditions

### Performance Optimization for Test Suites

#### Parallelization Strategies

While `terraform test` runs files sequentially, you can parallelize at the CI level:

```yaml
strategy:
  matrix:
    module: [vpc, ec2-instance, s3-bucket]

steps:
  - run: |
      cd modules/${{ matrix.module }}
      terraform test -verbose
```

#### Caching for Faster Tests

Provider caching reduces initialization time:

```yaml
- name: Cache Terraform Providers
  uses: actions/cache@v4
  with:
    path: ~/.terraform.d/plugin-cache
    key: terraform-providers-${{ hashFiles('**/.terraform.lock.hcl') }}

- name: Configure Provider Cache
  run: |
    mkdir -p ~/.terraform.d/plugin-cache
    echo "plugin_cache_dir = \"$HOME/.terraform.d/plugin-cache\"" > ~/.terraformrc
```

#### Minimizing Provider Initialization Overhead

1. **Use mock providers** for unit tests to skip provider download
2. **Cache provider plugins** across CI runs
3. **Share initialization** across tests in the same directory
4. **Limit integration tests** to essential scenarios

---

## Assumptions and Validation Notes

This section lists Terraform features and behaviors that **SHOULD** be verified against current official documentation before implementation.

### Features to Verify

| Feature | Documentation Source | Notes |
| --- | --- | --- |
| `terraform test` command | [Terraform Test Command](https://developer.hashicorp.com/terraform/cli/commands/test) | Verify current syntax and options |
| `.tftest.hcl` syntax | [Test File Reference](https://developer.hashicorp.com/terraform/language/tests) | Verify block types and attributes |
| `mock_provider` block | [Mock Providers](https://developer.hashicorp.com/terraform/language/tests#mocking-providers) | Verify mock capabilities |
| `expect_failures` | [Expecting Failures](https://developer.hashicorp.com/terraform/language/tests#expecting-failures) | Verify syntax for negative tests |
| `override_data`/`override_resource` | Mock override documentation | Verify per-run override syntax |
| CI action versions | GitHub Marketplace | Verify `hashicorp/setup-terraform@v3` is current |

### Version Compatibility

| Terraform Version | Test Framework Support |
| --- | --- |
| < 1.6.0 | Not supported (use Terratest) |
| 1.6.0 | Initial release of test framework |
| 1.7.0+ | Enhanced mock provider capabilities |

### Known Limitations

1. **Mock provider completeness:** Not all provider behaviors can be mocked
2. **Parallel execution:** Test files run sequentially
3. **State handling:** Integration tests manage state internally
4. **Provider credential requirements:** Integration tests require real credentials

---

## Summary of Recommended Implementation Steps

### CI/Infrastructure Implementation

1. **Verify existing workflow:** The `terraform-ci.yml` already includes a `test` job with proper configuration
2. **Create template test file:** Add `templates/terraform/Example.tftest.hcl` following the structure in Part 7
3. **Add sample module tests:** Create example `.tftest.hcl` files in any sample modules
4. **Update documentation:** Ensure README includes testing section
5. **Configure caching:** Verify provider caching is configured for test jobs

### terraform.instructions.md Content

1. **Verify existing section:** The "Testing with Terraform Test" section exists and covers most requirements
2. **Review Quick Reference Checklist:** Ensure all testing checklist items are present (currently they are)
3. **Add module test guidance:** Consider adding a checklist item for module testing
4. **Verify examples are complete:** Ensure all code examples are current and correct

### Template File Creation

1. **Create `templates/terraform/` directory** if it doesn't exist
2. **Create `Example.tftest.hcl`** following the template in Part 7
3. **Include comprehensive examples:** Mock providers, assertions, validation tests, output tests
4. **Add usage documentation:** Header comments explaining how to use the template

### Pre-commit and Tooling

1. **Verify `.tftest.hcl` formatting:** Confirm `terraform fmt` handles test files (it does)
2. **No additional hooks required:** Existing pre-commit configuration is sufficient
3. **Consider CI enhancements:** Optional matrix testing for multiple Terraform versions

### Documentation Updates

1. **Update README.md:** Add testing section with commands
2. **Verify copilot-instructions.md:** Terraform is already in the Testing Tools table
3. **Cross-reference guides:** Link this guide from terraform.instructions.md if desired

### Validation Steps

1. **Review official Terraform documentation** for any syntax changes
2. **Test example configurations** locally before committing
3. **Verify CI workflow** passes with test job enabled
4. **Run pre-commit checks** on all new files
