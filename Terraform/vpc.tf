# ==========================================
# VPC (Virtual Private Cloud) SETUP
# ==========================================
# This file creates our network infrastructure using a reusable VPC module
# Think of VPC as your private data center in AWS cloud

# Step 1: Create VPC using external module from GitHub
module "vpc" {
  # Source: Git repository containing the VPC module code
  # This is a reusable module that creates VPC, subnets, gateways, etc.
  source = "git::https://github.com/ShivaKrishna44/terraform-aws-vpc.git?ref=main"

  # Pass our variables to the VPC module
  # These tell the module how to configure our specific VPC
  project_name = var.project_name # Used for naming: "expense"
  environment  = var.environment  # Used for naming: "dev"
  vpc_cidr     = var.vpc_cidr     # IP range: "10.0.0.0/16"
  common_tags  = var.common_tags  # Tags for all VPC resources

  # Subnet configurations - these get passed to the module
  public_subnet_cidrs   = var.public_subnet_cidrs   # Where load balancers go
  private_subnet_cidrs  = var.private_subnet_cidrs  # Where app pods go
  database_subnet_cidrs = var.database_subnet_cidrs # Where databases go

  # Enable VPC peering for connecting to other VPCs if needed
  is_peering_required = true

  # What this module creates for us:
  # - 1 VPC with our CIDR block
  # - Public subnets (with Internet Gateway)
  # - Private subnets (with NAT Gateway)
  # - Database subnets (isolated)
  # - Route tables and security groups
  # - All necessary networking components
}

# ==========================================
# DATABASE SUBNET GROUP
# ==========================================
# RDS databases require a "subnet group" - a collection of subnets
# where the database can be placed for high availability

# Step 2: Create database subnet group for RDS instances
resource "aws_db_subnet_group" "expense" {
  # Name format: expense-dev (project-environment)
  name = "${var.project_name}-${var.environment}"

  # Use the database subnet IDs created by our VPC module
  # This references the outputs from the module above
  subnet_ids = module.vpc.database_subnet_ids

  # Why we need this:
  # - RDS requires subnets in multiple AZs for high availability
  # - This groups our database subnets together
  # - RDS can automatically failover between these subnets

  # Add descriptive tags for management and cost tracking
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}" # Display name in console
    Type = "Database"                               # Identifies this as DB infrastructure
  })
}

# What happens after this file runs:
# 1. VPC module creates complete network infrastructure
# 2. Database subnet group is ready for RDS instances
# 3. Other files can reference: module.vpc.vpc_id, module.vpc.private_subnet_ids, etc.
# 4. Network is properly segmented: public (internet) -> private (apps) -> database (isolated)