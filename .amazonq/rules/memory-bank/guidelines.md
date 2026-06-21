# Development Guidelines

## Code Quality Standards

### File Structure and Organization
- Use consistent directory structure with clear separation of concerns
- Group related resources in logical directories (app/, kubernetes/, Terraform/)
- Place environment-specific configurations in dedicated subdirectories (dev/, prod/)
- Keep configuration files separate from application code

### Naming Conventions
- **Variables**: Use snake_case for Terraform variables and local values
- **Resources**: Use kebab-case for Kubernetes resources and services
- **Files**: Use lowercase with hyphens or underscores for separation
- **Functions**: Use snake_case for Python function names
- **Constants**: Use UPPER_CASE for environment variables and constants

### Documentation Standards
- Include comprehensive inline comments explaining complex logic
- Use multi-line comments for section headers with clear visual separation
- Document the purpose and expected outcomes of each major component
- Provide context about dependencies and relationships between components

## Terraform Development Patterns

### Module Structure and Usage
```hcl
# Standard module invocation pattern
module "resource_name" {
  source  = "terraform-aws-modules/service/aws"
  version = "~> 20.0"
  
  # Basic configuration
  cluster_name    = var.cluster_name
  cluster_version = var.eks_version
  
  # Network configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}
```

### Resource Configuration Standards
- Always specify explicit versions for modules and providers
- Use descriptive variable names that clearly indicate their purpose
- Group related configuration blocks logically within resources
- Apply consistent tagging strategy using merge() function with common_tags

### Security Best Practices
- Place sensitive resources in private subnets by default
- Use IAM roles and policies with principle of least privilege
- Enable cluster creator admin permissions for initial setup
- Configure authentication modes supporting both API and ConfigMap

### Code Organization Patterns
- Separate infrastructure concerns into dedicated files (eks.tf, vpc.tf, iam.tf)
- Use local values for complex expressions and repeated configurations
- Maintain environment-specific variable files (dev.tfvars, prod.tfvars)
- Keep backend configurations separate from main code

## Python Application Development

### Flask Application Structure
```python
from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "Hello from Service Name"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

### Container Development Standards
- Use official Python base images with specific versions (python:3.12-slim)
- Set WORKDIR to /app for consistency across all services
- Copy application files and install dependencies in correct order
- Expose standard port 5000 for Flask applications
- Use CMD instruction with explicit python command and app file

### Microservice Consistency
- Maintain identical application structure across all services
- Use consistent port numbers and host configurations
- Apply uniform error handling and logging patterns
- Follow same dependency management approach with requirements.txt

## Infrastructure as Code Practices

### Configuration Management
- Use environment variables for dynamic configuration values
- Store sensitive values in AWS Systems Manager or similar secure storage
- Maintain separate configuration files for different environments
- Export common variables in configuration scripts for reusability

### Resource Tagging Strategy
```hcl
tags = merge(var.common_tags, {
  Name = var.resource_name
  Type = "Resource-Type"
})
```

### Network Security Patterns
- Configure security groups with explicit rules for required communication
- Use descriptive names for security group rules explaining their purpose
- Follow principle of least privilege for network access
- Document security group rules with clear descriptions

## Kubernetes and Container Standards

### Dockerfile Best Practices
- Use multi-stage builds when appropriate for optimization
- Minimize layer count by combining related RUN commands
- Copy requirements files before application code for better caching
- Use specific version tags rather than 'latest' for base images

### YAML Configuration Standards
- Use consistent indentation (2 spaces) throughout all YAML files
- Group related configuration sections with appropriate comments
- Apply descriptive names for resources that indicate their purpose
- Use namespace separation for different application components

### Helm Chart Patterns
- Separate configuration values into environment-specific files
- Use consistent naming for values and template references
- Document all configurable values with appropriate defaults
- Apply security best practices for service accounts and RBAC

## Script Development Guidelines

### Shell Script Standards
- Use bash shebang (#!/bin/bash) for all shell scripts
- Export environment variables with descriptive names in ALL_CAPS
- Group related configuration variables together
- Use consistent variable naming conventions across all scripts

### Automation Patterns
- Create modular scripts for specific installation tasks (01-install-tools.sh)
- Use sequential numbering for scripts that must run in order
- Include error handling and validation in automation scripts
- Document script dependencies and prerequisites

## Error Handling and Validation

### Terraform Validation
- Use appropriate data sources for resource validation
- Implement proper dependency management between resources
- Include validation rules for critical configuration parameters
- Test infrastructure changes in development environments first

### Application Error Handling
- Implement consistent error response patterns across microservices
- Use appropriate HTTP status codes for different error conditions
- Log errors with sufficient context for debugging
- Provide meaningful error messages for API consumers

## Performance and Optimization

### Resource Optimization
- Use appropriate instance types and sizes for workloads
- Configure auto-scaling groups with realistic min/max values
- Optimize container images by using slim base images
- Implement proper resource requests and limits in Kubernetes

### Build Optimization
- Layer Docker builds to take advantage of caching
- Use .dockerignore files to exclude unnecessary files
- Minimize container image size through multi-stage builds
- Cache dependencies appropriately in CI/CD pipelines