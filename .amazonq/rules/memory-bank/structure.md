# Project Structure

## Directory Organization

### `/app/` - Microservices Applications
- **`order-service/`**: Order management microservice
- **`payment-service/`**: Payment processing microservice with Flask app
- **`user-service/`**: User management microservice with Flask app
- Each service contains Dockerfile and Python application code

### `/Terraform/` - Infrastructure as Code
- **`eks.tf`**: EKS cluster configuration and management
- **`vpc.tf`**: Virtual Private Cloud and network setup
- **`ecr.tf`**: Elastic Container Registry repositories
- **`iam-*.tf`**: IAM roles, policies, and service accounts
- **`eks-addons.tf`**: EKS cluster add-ons configuration
- **`tfvars/`**: Environment-specific variables (dev/prod)
- **`policies/`**: AWS IAM policy documents
- **`modules/`**: Reusable Terraform modules (EKS, VPC, KMS)

### `/kubernetes/` - Kubernetes Configurations
- **`namespaces/`**: Namespace definitions for different services
- **`jenkins/`**: Jenkins Helm values and configuration
- **`argocd/`**: ArgoCD deployment and ingress configuration
- **`monitoring/`**: Grafana and monitoring stack configuration
- **`ingress/`**: Application load balancer and ingress rules

### `/scripts/` - Automation Scripts
- **`01-install-tools.sh`**: Initial tool installation
- **`02-install-alb-controller.sh`**: AWS Load Balancer Controller setup
- **`03-install-jenkins.sh`**: Jenkins deployment automation
- **`04-install-argocd.sh`**: ArgoCD installation script
- **`05-install-monitoring.sh`**: Monitoring stack deployment
- **`config.sh`**: Common configuration and variables

## Core Components & Relationships

### Infrastructure Layer
- **Terraform modules** provision AWS resources (EKS, VPC, ECR)
- **VPC module** creates network foundation with subnets and security groups
- **EKS module** manages Kubernetes cluster with node groups and add-ons

### Platform Layer  
- **Jenkins** provides CI/CD capabilities with Kubernetes integration
- **ArgoCD** handles GitOps-based continuous deployment
- **AWS Load Balancer Controller** manages ingress traffic routing
- **Grafana** delivers monitoring and observability

### Application Layer
- **Microservices** (payment, user, order) implement business logic
- **Docker containers** package applications for Kubernetes deployment
- **Ingress controllers** route external traffic to services

## Architectural Patterns

### Infrastructure as Code (IaC)
- Declarative infrastructure using Terraform
- Environment separation through tfvars configuration
- Modular design for reusability across environments

### GitOps Workflow
- Infrastructure changes tracked in Git
- ArgoCD synchronizes desired state from Git repositories
- Automated deployment pipelines trigger on code changes

### Microservices Architecture
- Service decomposition by business capability
- Container-based deployment with Docker
- Kubernetes orchestration for scaling and management

### Multi-Environment Strategy
- Separate configurations for dev/prod environments
- Environment-specific variable files and backends
- Consistent deployment patterns across environments