# ==========================================
# DATA SOURCES
# ==========================================
# Data sources READ information from AWS without creating any resources.
# They are used to look up existing values at plan/apply time.
# Think of them as "queries" to AWS — read-only, no infrastructure changes.

# ==========================================
# Availability Zones
# ==========================================
# Fetches all available AZs in the current region (e.g., us-east-1a, us-east-1b)
# Used by: VPC module to spread subnets across multiple AZs for high availability
# Example output: ["us-east-1a", "us-east-1b", "us-east-1c"]
data "aws_availability_zones" "available" {
  state = "available" # Only return AZs that are currently operational (excludes impaired ones)
}

# ==========================================
# Current AWS Account Identity
# ==========================================
# Returns the AWS account ID, user ARN, and user ID of whoever is running Terraform
# Used by: ECR repository URIs, IAM policies, OIDC trust policies
# Example: data.aws_caller_identity.current.account_id → "589389425618"
data "aws_caller_identity" "current" {}

# ==========================================
# Current AWS Region
# ==========================================
# Returns the region configured in the AWS provider (e.g., "us-east-1")
# Used by: constructing ARNs, ECR registry URLs, region-specific resource names
# Example: data.aws_region.current.name → "us-east-1"
data "aws_region" "current" {}
