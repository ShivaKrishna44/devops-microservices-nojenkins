# ==========================================
# SSM PARAMETERS FOR INFRASTRUCTURE DATA SHARING
# ==========================================
# This file stores important infrastructure values in AWS Systems Manager Parameter Store
# Other applications and Terraform configurations can read these values
# Think of it as a centralized configuration database

# Step 1: Store VPC ID for other services to use
resource "aws_ssm_parameter" "vpc_id" {
  # Parameter name format: /project/environment/resource_type
  name  = "/${var.project_name}/${var.environment}/vpc_id"
  type  = "String"          # Simple string value
  value = module.vpc.vpc_id # VPC ID from our VPC module

  # Why store this?
  # - Other applications need to know which VPC to deploy into
  # - Lambda functions, RDS instances, etc. can read this value
  # - Avoids hardcoding VPC IDs in multiple places

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc-id"
    Type = "Infrastructure-Config" # Identifies as config parameter
  })
}

# Step 2: Store private subnet IDs (where applications run)
resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/${var.project_name}/${var.environment}/private_subnet_ids"
  type  = "StringList"                             # Comma-separated list
  value = join(",", module.vpc.private_subnet_ids) # Convert list to string

  # Why store this?
  # - Applications need to know which subnets to deploy into
  # - RDS, Lambda, ECS services can use these subnets
  # - Ensures consistent subnet usage across services

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-subnet-ids"
    Type = "Infrastructure-Config"
  })
}

# Step 3: Store public subnet IDs (where load balancers go)
resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "/${var.project_name}/${var.environment}/public_subnet_ids"
  type  = "StringList"
  value = join(",", module.vpc.public_subnet_ids)

  # Why store this?
  # - ALB/NLB load balancers need public subnets
  # - NAT gateways are placed in public subnets
  # - Bastion hosts or public-facing services use these

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-subnet-ids"
    Type = "Infrastructure-Config"
  })
}

# Step 4: Store database subnet IDs (isolated database layer)
resource "aws_ssm_parameter" "database_subnet_ids" {
  name  = "/${var.project_name}/${var.environment}/database_subnet_ids"
  type  = "StringList"
  value = join(",", module.vpc.database_subnet_ids)

  # Why store this?
  # - RDS instances are deployed in database subnets
  # - ElastiCache clusters use database subnets
  # - Provides network isolation for data layer

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-database-subnet-ids"
    Type = "Infrastructure-Config"
  })
}

# Step 5: Store database subnet group name (for RDS)
resource "aws_ssm_parameter" "database_subnet_group_name" {
  name  = "/${var.project_name}/${var.environment}/database_subnet_group_name"
  type  = "String"
  value = aws_db_subnet_group.expense.name # From vpc.tf

  # Why store this?
  # - RDS instances require a subnet group parameter
  # - Terraform configurations for databases can reference this
  # - Avoids recreating subnet groups in multiple places

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-group-name"
    Type = "Infrastructure-Config"
  })
}

# How to use these parameters:
# 1. In Terraform: data "aws_ssm_parameter" "vpc_id" { name = "/expense/dev/vpc_id" }
# 2. In AWS CLI: aws ssm get-parameter --name "/expense/dev/vpc_id"
# 3. In applications: Use AWS SDK to read parameter values
# 4. In other Terraform configs: Reference these for consistent infrastructure

# Benefits:
# - Centralized configuration management
# - No hardcoded values in application code
# - Easy to change environments (dev -> prod)
# - Audit trail of configuration changes
# - Version history of parameter values