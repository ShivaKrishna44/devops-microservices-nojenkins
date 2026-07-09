# ==========================================
# DISASTER RECOVERY REGION (us-west-2)
# ==========================================
# Warm Standby: minimal infra running, scales up on failover
# NOT applied by default — only deploy when DR is needed
# To activate: terraform apply -var-file=tfvars/dr/dr.tfvars -target=module.dr_vpc -target=module.dr_eks
#
# Strategy: Warm Standby
# RTO: < 15 minutes
# RPO: < 5 minutes (ECR replication + S3 CRR)
# ==========================================

# DR Region Provider
provider "aws" {
  alias  = "dr"
  region = "us-west-2"
}

# ==========================================
# DR VPC (same structure as primary)
# ==========================================
module "dr_vpc" {
  source = "git::https://github.com/ShivaKrishna44/terraform-aws-vpc.git?ref=main"

  providers = {
    aws = aws.dr
  }

  project_name = var.project_name
  environment  = "${var.environment}-dr"
  vpc_cidr     = "10.1.0.0/16" # Different CIDR from primary (10.0.0.0/16)
  common_tags = merge(var.common_tags, {
    Region = "us-west-2"
    Type   = "DR"
  })

  public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs  = ["10.1.11.0/24", "10.1.12.0/24"]
  database_subnet_cidrs = ["10.1.21.0/24", "10.1.22.0/24"]

  is_peering_required = false
}

# ==========================================
# DR EKS Cluster (minimal — 1 node, scales up on failover)
# ==========================================
module "dr_eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  providers = {
    aws = aws.dr
  }

  cluster_name    = "${var.cluster_name}-dr"
  cluster_version = var.eks_version

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true
  authentication_mode = "API_AND_CONFIG_MAP"

  vpc_id     = module.dr_vpc.vpc_id
  subnet_ids = module.dr_vpc.private_subnet_ids

  # Minimal node group — warm standby (1 small node)
  eks_managed_node_groups = {
    dr_nodes = {
      instance_types = ["t3.small"] # Smaller than primary
      min_size       = 1
      max_size       = 5  # Scales up during failover
      desired_size   = 1  # Only 1 node in standby
      disk_size      = 20

      labels = {
        Environment = "dr"
        Role        = "warm-standby"
      }
    }
  }

  tags = merge(var.common_tags, {
    Name   = "${var.cluster_name}-dr"
    Region = "us-west-2"
    Type   = "DR-Warm-Standby"
  })
}

# ==========================================
# ECR Replication (primary → DR region)
# ==========================================
resource "aws_ecr_replication_configuration" "dr_replication" {
  replication_configuration {
    rule {
      destination {
        region      = "us-west-2"
        registry_id = data.aws_caller_identity.current.account_id
      }

      # Only replicate images with specific tags
      repository_filter {
        filter      = "order-service"
        filter_type = "PREFIX_MATCH"
      }
      repository_filter {
        filter      = "payment-service"
        filter_type = "PREFIX_MATCH"
      }
      repository_filter {
        filter      = "user-service"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

# ==========================================
# Route53 Health Check (monitors primary ALB)
# ==========================================
resource "aws_route53_health_check" "primary_health" {
  fqdn              = "app.vosukula.online"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/order"
  failure_threshold = 3
  request_interval  = 10

  tags = {
    Name = "primary-region-health-check"
  }
}

# ==========================================
# Route53 Failover Records
# ==========================================
# Primary record (active)
resource "aws_route53_record" "app_primary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "app.vosukula.online"
  type    = "CNAME"
  ttl     = 60 # Low TTL for fast failover

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary_health.id
  records         = ["PRIMARY_ALB_DNS_HERE"] # Replace with actual ALB DNS
}

# DR record (standby — activated when primary health check fails)
resource "aws_route53_record" "app_dr" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "app.vosukula.online"
  type    = "CNAME"
  ttl     = 60

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "dr"
  records        = ["DR_ALB_DNS_HERE"] # Replace with DR ALB DNS when activated
}

# Data source for Route53 zone
data "aws_route53_zone" "main" {
  name = "vosukula.online"
}
