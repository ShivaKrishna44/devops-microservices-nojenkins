# ==========================================
# TERRAFORM PROVIDER CONFIGURATION
# ==========================================
# This file configures which Terraform version and AWS provider to use
# It's like telling Terraform what tools and versions it needs to work with

# Step 1: Define Terraform requirements and constraints
terraform {
  # Minimum Terraform version required for this configuration
  # Using >= 1.10 ensures we have latest features and bug fixes
  required_version = ">= 1.10"

  # Step 2: Specify which providers (cloud services) we'll use
  required_providers {
    aws = {
      # Source: Where to download the AWS provider from
      source = "hashicorp/aws"
      # Version: Use AWS provider version 6.0 or compatible newer versions
      # The ~> means "pessimistic constraint" - allows 6.1, 6.2, etc. but not 7.0
      # Updated to match installed binary 6.51.0
      version = "~> 6.0"
    }
  }
}

# Step 3: Configure the AWS provider settings
provider "aws" {
  # Default AWS region where all resources will be created
  # us-east-1 is Virginia region - popular choice for many services
  region = "us-east-1"

  # Note: AWS credentials should be configured via:
  # - Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
  # - AWS CLI configuration (~/.aws/credentials)
  # - IAM roles (when running on EC2)
  # Never hardcode credentials in Terraform files!
}