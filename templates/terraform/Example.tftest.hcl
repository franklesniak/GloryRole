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
#   - Terraform 1.7.0 or later (mock_provider requires 1.7.0+)
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
    environment = "invalid" # Should fail validation
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
