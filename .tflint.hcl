# TFLint Configuration
# https://github.com/terraform-linters/tflint

config {
  format = "compact"

  call_module_type    = "local"
  force               = false
  disabled_by_default = false
}

# Terraform plugin for general linting
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS-specific rules (uncomment if using AWS)
# plugin "aws" {
#   enabled = true
#   version = "0.32.0"
#   source  = "github.com/terraform-linters/tflint-ruleset-aws"
# }

# Azure-specific rules (uncomment if using Azure)
# plugin "azurerm" {
#   enabled = true
#   version = "0.27.0"
#   source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
# }

# Google Cloud-specific rules (uncomment if using GCP)
# plugin "google" {
#   enabled = true
#   version = "0.30.0"
#   source  = "github.com/terraform-linters/tflint-ruleset-google"
# }

# ============================================================================
# Rule Configuration
# ============================================================================

# Enforce snake_case naming convention for all Terraform identifiers
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Require descriptions for all variables
rule "terraform_documented_variables" {
  enabled = true
}

# Require descriptions for all outputs
rule "terraform_documented_outputs" {
  enabled = true
}

# Require type declarations for all variables
rule "terraform_typed_variables" {
  enabled = true
}

# Warn on deprecated syntax
rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Warn on unused declarations
rule "terraform_unused_declarations" {
  enabled = true
}

# Require version constraints for modules
rule "terraform_module_version" {
  enabled = true
}

# Require version constraints for providers
rule "terraform_required_providers" {
  enabled = true
}

# Require required_version for Terraform
rule "terraform_required_version" {
  enabled = true
}

# Enforce standard file structure
rule "terraform_standard_module_structure" {
  enabled = true
}

# Workspace usage warning
rule "terraform_workspace_remote" {
  enabled = true
}
