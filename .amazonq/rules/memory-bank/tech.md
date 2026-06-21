# Technology Stack

## Programming Languages & Frameworks

### Python 3.x
- **Flask Framework**: Microservices development (payment-service, user-service)
- **Requirements**: Dependencies managed via requirements.txt files
- **Container Runtime**: Python applications containerized with Docker

### Shell Scripting (Bash)
- **Automation Scripts**: Complete platform setup and configuration
- **Tool Installation**: Automated deployment of Kubernetes tools
- **Environment Configuration**: System setup and variable management

## Infrastructure & Cloud Technologies

### AWS Services
- **Amazon EKS**: Managed Kubernetes service for container orchestration
- **Amazon VPC**: Virtual private cloud networking
- **Amazon ECR**: Container registry for Docker images
- **AWS IAM**: Identity and access management with IRSA
- **AWS Load Balancer**: Application load balancing and ingress

### Kubernetes Ecosystem
- **Kubernetes 1.x**: Container orchestration platform
- **Helm**: Package manager for Kubernetes applications
- **kubectl**: Command-line interface for Kubernetes management
- **Ingress Controllers**: Traffic routing and load balancing

## Infrastructure as Code

### Terraform
- **Version**: HashiCorp Terraform with AWS Provider 5.x/6.x
- **Modules**: EKS, VPC, KMS modules for reusable infrastructure
- **State Management**: Remote state with backend configuration
- **Providers**: AWS, CloudInit, Null, Time, TLS providers

### Configuration Management
- **YAML**: Kubernetes manifests and Helm values
- **HCL**: Terraform configuration language
- **JSON**: AWS policy documents and configuration files

## CI/CD & DevOps Tools

### Jenkins
- **Version**: Latest stable with Kubernetes plugin
- **Plugins**: workflow-aggregator, git, docker-workflow, configuration-as-code
- **Storage**: Persistent volumes with GP2 storage class (10Gi)
- **Authentication**: Admin user with basic authentication

### ArgoCD
- **GitOps Platform**: Continuous deployment from Git repositories
- **Kubernetes Native**: Declarative application management
- **Web UI**: Application dashboard and deployment monitoring

### Monitoring & Observability
- **Grafana**: Metrics visualization and dashboarding
- **Kubernetes Metrics**: Built-in monitoring capabilities
- **Health Checks**: Service availability monitoring

## Development Commands & Tools

### Container Operations
```bash
# Build Docker images
docker build -t <service-name> .

# Push to ECR
docker push <ecr-registry>/<service-name>:latest
```

### Terraform Operations
```bash
# Initialize Terraform
terraform init -backend-config=tfvars/dev/backend.tfvars

# Plan infrastructure changes
terraform plan -var-file=tfvars/dev/dev.tfvars

# Apply infrastructure
terraform apply -var-file=tfvars/dev/dev.tfvars
```

### Kubernetes Deployment
```bash
# Apply Kubernetes manifests
kubectl apply -f kubernetes/

# Install Helm charts
helm install jenkins jenkins/jenkins -f kubernetes/jenkins/jenkins-values.yaml

# Check cluster status
kubectl get nodes, pods --all-namespaces
```

### Platform Setup
```bash
# Complete platform installation
./scripts/01-install-tools.sh
./scripts/02-install-alb-controller.sh  
./scripts/03-install-jenkins.sh
./scripts/04-install-argocd.sh
./scripts/05-install-monitoring.sh
```

## Build System & Dependencies

### Docker
- **Multi-stage builds**: Optimized container images
- **Base images**: Python official images for microservices
- **Layer caching**: Efficient build processes

### Helm Charts
- **Package management**: Kubernetes application deployment
- **Values customization**: Environment-specific configurations
- **Release management**: Version control for deployments

### Environment Management
- **Development**: Local development with dev.tfvars
- **Production**: Production deployment with prod.tfvars
- **Backend Configuration**: Separate state management per environment