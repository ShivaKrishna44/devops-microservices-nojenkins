variable "environment" { type = string; default = "dev" }
variable "project_name" { type = string; default = "expense" }
variable "domain_name" { type = string; default = "vosukula.online" }
variable "instance_type" { type = string; default = "t3.micro" }
variable "vpc_cidr" { type = string; default = "10.0.0.0/16" }
variable "public_subnet_cidrs" { type = list(string); default = ["10.0.1.0/24", "10.0.2.0/24"] }
variable "private_subnet_cidrs" { type = list(string); default = ["10.0.11.0/24", "10.0.12.0/24"] }
variable "database_subnet_cidrs" { type = list(string); default = ["10.0.21.0/24", "10.0.22.0/24"] }
variable "cluster_name" { type = string; default = "expense" }
variable "eks_version" { type = string; default = "1.30" }
variable "node_group_instance_type" { type = string; default = "t3.medium" }
variable "min_size" { type = number; default = 1 }
variable "max_size" { type = number; default = 3 }
variable "desired_size" { type = number; default = 2 }
variable "common_tags" { type = map(string); default = { Project = "microservices", Environment = "dev", Terraform = "true" } }
variable "vpc_tags" { type = map(string); default = { Purpose = "assignment" } }
