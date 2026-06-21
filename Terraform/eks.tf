# ==========================================
# EKS (Elastic Kubernetes Service) CLUSTER
# ==========================================
# This file creates a managed Kubernetes cluster in AWS
# EKS handles the Kubernetes control plane (API server, etcd, scheduler)

# Step 1: Create EKS cluster using the official AWS EKS module
module "eks" {
  # Source: Official EKS module from Terraform registry
  # This module is maintained by AWS and includes best practices
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0" # Use version 20.x (latest stable)

  # Basic cluster configuration
  cluster_name    = var.cluster_name # Name: "expense-dev"
  cluster_version = var.eks_version  # Kubernetes version: "1.33"

  # Network access configuration
  # Allow public access to cluster API endpoint (can be restricted later)
  cluster_endpoint_public_access = true

  # Security: Give cluster creator admin permissions automatically
  # This allows the person running terraform to manage the cluster
  enable_cluster_creator_admin_permissions = true

  # Authentication mode: Use both API and ConfigMap for backwards compatibility
  # API mode is newer, ConfigMap is legacy but still supported
  authentication_mode = "API_AND_CONFIG_MAP"

  # Network configuration - where to place the cluster
  vpc_id     = module.vpc.vpc_id             # Use our VPC created in vpc.tf
  subnet_ids = module.vpc.private_subnet_ids # Place cluster in private subnets (more secure)

  # Worker node configuration - where pods will run
  eks_managed_node_groups = local.eks_managed_node_groups # Defined in local.tf

  # Step 2: Configure AWS user/role access to EKS cluster
  # This gives specific AWS accounts admin access to the cluster
  access_entries = {
    root_admin = {
      # ARN of AWS account root user (replace with your account ID)
      principal_arn = "arn:aws:iam::589389425618:root"

      # Grant admin policy to this user/role
      policy_associations = {
        admin = {
          # AWS managed policy for cluster admin access
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

          # Scope: cluster-wide access (not namespace-specific)
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    # You can add more entries here for different users/roles:
    # developer = { principal_arn = "arn:aws:iam::account:user/dev-user", ... }
  }

  # Step 3: Configure security groups for worker nodes
  create_node_security_group = true
  node_security_group_additional_rules = {
    # Allow nodes to communicate with each other on all ports
    # This is required for pod-to-pod networking and CNI
    ingress_self_all = {
      description = "Node to node all ports/protocols - required for pod networking"
      protocol    = "-1"      # -1 means all protocols (TCP, UDP, ICMP)
      from_port   = 0         # All ports
      to_port     = 0         # All ports
      type        = "ingress" # Incoming traffic
      self        = true      # From same security group (node-to-node)
    }
  }

  # Step 4: Apply consistent tags to all EKS resources
  tags = merge(var.common_tags, {
    Name = var.cluster_name # Display name in AWS console
    Type = "EKS-Cluster"    # Resource type identifier
  })
}

# What this creates:
# 1. EKS Control Plane (managed by AWS)
#    - Kubernetes API server
#    - etcd database
#    - Scheduler and controller manager
# 2. Worker Node Groups (EC2 instances)
#    - Auto Scaling Groups
#    - Launch Templates
#    - Security Groups
# 3. OIDC Provider (for IAM roles for service accounts)
# 4. Cluster security groups and networking
# 5. Access entries for user authentication

# After this runs, you can:
# - Connect with: aws eks update-kubeconfig --name expense-dev
# - Deploy applications using kubectl
# - Use Helm charts for complex applications
# - Set up monitoring and logging