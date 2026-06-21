# ==========================================
# LOCAL VALUES AND COMPUTED CONFIGURATIONS
# ==========================================
# This file defines local values that are computed or derived from variables
# Locals help avoid repetition and make complex expressions reusable

# Step 1: Define all local values
locals {
  # EKS managed node groups configuration
  # This defines the worker nodes where your Kubernetes pods will run
  eks_managed_node_groups = {
    # Dynamic key based on environment (dev, prod, etc.)
    # This creates a node group named after your environment
    "${var.environment}" = {
      # EC2 instance types for worker nodes
      # You can specify multiple types for mixed instance groups
      instance_types = [var.node_group_instance_type] # e.g., ["t3.medium"]

      # Auto Scaling configuration
      desired_size = var.desired_size # Target number of nodes (e.g., 2)
      min_size     = var.min_size     # Minimum nodes during scale-down (e.g., 1)
      max_size     = var.max_size     # Maximum nodes during scale-up (e.g., 3)

      # IAM role for node group (references role created in iam.tf)
      # This gives worker nodes permissions to join cluster and pull images
      iam_role_arn = aws_iam_role.node_group.arn

      # Additional node group settings that could be added:
      # ami_type = "AL2_x86_64"          # Amazon Linux 2
      # capacity_type = "ON_DEMAND"      # Or "SPOT" for cost savings
      # disk_size = 20                   # EBS volume size in GB
      # labels = { role = "worker" }     # Kubernetes labels
      # taints = []                      # Kubernetes taints
    }
  }
}

# Why use locals?
# 1. Avoid repeating complex expressions
# 2. Compute values based on variables
# 3. Make configurations more readable
# 4. Centralize derived values

# How this is used:
# - The eks.tf file references: local.eks_managed_node_groups
# - This creates a node group with the specified configuration
# - Auto Scaling Group will maintain desired number of nodes
# - Nodes will have proper IAM permissions to join cluster