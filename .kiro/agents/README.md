# Multi-Agent System — devops-microservices-platform

Each agent maps to a specific stage of the project pipeline. Use them in Kiro chat by referencing the agent name.

## Agent Map

```
┌─────────────────────────────────────────────────────────────┐
│                   PROJECT PIPELINE                          │
├──────────────┬──────────────────────────────────────────────┤
│  Stage       │  Agent            │  Scope                   │
├──────────────┼───────────────────┼──────────────────────────┤
│  1. Infra    │  infra-agent      │  Terraform, EKS, IAM     │
│  2. Tools    │  tools-agent      │  Helm, kubectl, ALB      │
│  3. CI/CD    │  cicd-agent       │  Jenkins, Jenkinsfile    │
│  4. Build    │  build-agent      │  Docker, ECR, app code   │
│  5. Deploy   │  deploy-agent     │  ArgoCD, K8s manifests   │
│  6. Monitor  │  monitoring-agent │  Prometheus, Grafana     │
└──────────────┴───────────────────┴──────────────────────────┘
```

## Agents

### infra-agent
Terraform infrastructure, EKS cluster, VPC, IAM roles.
- Files: `Terraform/**`, `.terraform.lock.hcl`

### tools-agent
Helm/kubectl setup, ALB controller installation.
- Files: `scripts/01-install-tools.sh`, `scripts/02-install-alb-controller.sh`

### cicd-agent
Jenkins pipeline, Jenkinsfile, Jenkins Helm values.
- Files: `Jenkinsfile`, `scripts/03-install-jenkins.sh`, `kubernetes/jenkins/**`

### build-agent
Python microservice code, Dockerfiles, ECR image build and push.
- Files: `app/**` (order-service, payment-service, user-service)

### deploy-agent
ArgoCD GitOps, Kubernetes manifests, namespace management.
- Files: `scripts/04-install-argocd.sh`, `kubernetes/argocd/**`, `kubernetes/namespaces/**`

### monitoring-agent
Prometheus, Grafana, Alertmanager via kube-prometheus-stack.
- Files: `scripts/05-install-monitoring.sh`, `kubernetes/monitoring/**`

## Project Config Reference
| Key | Value |
|---|---|
| AWS Region | us-east-1 |
| EKS Cluster | expense-dev |
| AWS Account | 589389425618 |
| Domain | vosukula.online |
| Jenkins URL | https://jenkins.vosukula.online |
| ArgoCD URL | https://argocd.vosukula.online |
| App URL | https://app.vosukula.online |
