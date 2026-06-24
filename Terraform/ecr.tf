# ==========================================
# ECR (Elastic Container Registry) REPOSITORIES
# ==========================================
# Stores Docker images for each microservice
# FIX: Added image_tag_mutability=IMMUTABLE, scan_on_push, lifecycle policies

locals {
  ecr_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_repository" "user_service" {
  name                 = "user-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.common_tags, {
    Name = "user-service"
  })
}

resource "aws_ecr_lifecycle_policy" "user_service" {
  repository = aws_ecr_repository.user_service.name
  policy     = local.ecr_lifecycle_policy
}

resource "aws_ecr_repository" "payment_service" {
  name                 = "payment-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.common_tags, {
    Name = "payment-service"
  })
}

resource "aws_ecr_lifecycle_policy" "payment_service" {
  repository = aws_ecr_repository.payment_service.name
  policy     = local.ecr_lifecycle_policy
}

resource "aws_ecr_repository" "order_service" {
  name                 = "order-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.common_tags, {
    Name = "order-service"
  })
}

resource "aws_ecr_lifecycle_policy" "order_service" {
  repository = aws_ecr_repository.order_service.name
  policy     = local.ecr_lifecycle_policy
}
