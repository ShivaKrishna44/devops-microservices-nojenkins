locals {
  vpc_tags = merge(var.common_tags, var.vpc_tags, { Name = "${var.cluster_name}-${var.environment}-vpc" })
  private_subnets = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  eks_managed_node_groups = {
    dev = {
      instance_types = [var.node_group_instance_type]
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.desired_size
    }
  }
}
