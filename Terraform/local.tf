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
    }
  }
}
