# IC Markets — DevOps Engineer Interview Prep

---

## How to Position Yourself

> "I'm a Senior DevOps Engineer with 8+ years building cloud-native platforms on AWS. My core strength is designing EKS-based microservices platforms with full CI/CD automation, GitOps deployments, and production-grade monitoring. I've worked on high-availability systems where uptime is critical — similar to trading platforms. I bring hands-on experience with Terraform, Kubernetes, Jenkins, GitHub Actions, and event-driven architectures on AWS."

---

## Your Experience Mapped to Their Requirements

| Their Requirement | Your Experience (say this) |
|---|---|
| AWS infrastructure for trading platforms | "I manage EKS clusters on AWS with VPC, private subnets, ALBs, IRSA, ECR — all via Terraform" |
| IaC with Terraform/CloudFormation | "I write modular Terraform — VPC, EKS, ECR, IAM roles. State in S3 + DynamoDB locking" |
| CI/CD — CodePipeline, Jenkins, GitHub Actions | "I've built pipelines in both Jenkins (declarative, distributed agents) and GitHub Actions (OIDC + ArgoCD)" |
| ECS/EKS/Fargate | "I manage EKS clusters with Helm charts, HPA autoscaling, and Argo Rollouts for canary deployments" |
| Service discovery + load balancing | "I use AWS ALB Ingress Controller with shared ALB groups for host-based routing across namespaces" |
| Event-driven (EventBridge, SQS, SNS, Lambda) | "I've designed event-driven flows where services communicate via SQS queues and SNS topics" |
| IAM best practices, security | "I use IRSA for pod-level AWS access, OIDC for CI/CD auth, least-privilege policies, no static keys" |
| VPC, Direct Connect, Transit Gateway | "I design VPCs with public/private/database subnets, NAT gateways, and security group isolation" |
| Monitoring — CloudWatch, Prometheus, Grafana | "I run kube-prometheus-stack on EKS — Prometheus metrics, Grafana dashboards, custom alerts" |
| DR, backups, Multi-AZ | "My EKS nodes span 2 AZs, RDS is Multi-AZ, and I use S3 CRR for cross-region data replication" |

---

## Expected Questions & Answers

### 1. Cloud Infrastructure & Automation

**Q: How do you design highly available infrastructure on AWS?**

> "Multi-AZ everything. EKS nodes across 2+ AZs, ALB with cross-zone balancing, RDS Multi-AZ for automatic failover. NAT Gateways in each AZ so private subnets have redundant internet access. All provisioned via Terraform so it's reproducible — if one AZ dies, workloads automatically shift to the surviving AZ."
<img width="1408" height="768" alt="image_d9738eb" src="https://github.com/user-attachments/assets/dc9ebc4f-65c8-4470-a215-55f50a33eb36" />

**Q: How do you manage Terraform at scale?**

> "I use modular Terraform — separate files for VPC, EKS, ECR, IAM. Remote state in S3 with DynamoDB locking so teams don't conflict. Environment separation via tfvars (dev/prod). I pin provider versions and commit `.terraform.lock.hcl` to prevent drift. For drift detection, I run `terraform plan -refresh-only` on a schedule."


# VPC Module Reference vpc.tf
module "vpc" {
  source      = "./modules/vpc"
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  az_count    = var.az_count
}
# IAM Module Reference iam.tf
module "iam" {
  source      = "./modules/iam"
  environment = var.environment
}
# ECR Module Reference ecr.tf
module "ecr" {
  source          = "./modules/ecr"
  environment     = var.environment
  repo_names      = ["frontend", "backend"]
  iam_push_arn   = module.iam.ecr_push_role_arn
}

# EKS Module Reference eks.tf
module "eks" {
  source             = "./modules/eks"
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = var.node_instance_type
}

# Remote State configuration with DynamoDB State Locking
  backend "s3" {
    bucket         = "your-company-terraform-state"
    key            = "environments/terraform.tfstate" # Overridden in CI via -backend-config
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }

**Environment Input Files (.tfvars)hcl# environments/dev.tfvars**
environment        = "dev"
vpc_cidr           = "10.0.0.0/16"
az_count           = 2
node_instance_type = "t3.medium"
Use code with caution.hcl# environments/prod.tfvars
environment        = "prod"
vpc_cidr           = "10.10.0.0/16"
az_count           = 3
node_instance_type = "m5.large"

**Q: Tell me about a CI/CD pipeline you've built.**

> "I built a GitHub Actions pipeline that uses OIDC to authenticate to AWS — no stored credentials. It builds Docker images, pushes to ECR with commit SHA tags, then updates Helm values in Git. ArgoCD detects the change and auto-syncs to EKS. For the Jenkins version, I had a distributed agent model with EC2 agents connecting via WebSocket, running parallel build+test stages and SonarQube quality gates."

---

### 2. Containerization & Orchestration

**Q: How do you manage EKS clusters?**

> "I provision EKS with Terraform using the official module. Managed node groups with t3.medium instances. I use Helm for deploying services — each microservice has its own namespace. HPA handles autoscaling based on CPU. For deployments, ArgoCD watches Git and auto-syncs. I've also set up Argo Rollouts for canary deployments on critical services."

**Q: How do you optimize Kubernetes for cost?**

> "Reduce HPA minReplicas to 1 in dev environments. Use shared ALBs (group.name annotation) instead of per-service ALBs — saves $48/month per cluster. Right-size resource requests based on actual usage from Prometheus metrics. Spot instances for non-critical workloads. ECR lifecycle policies to limit stored images."

**Q: How do you handle service discovery and load balancing?**

> "For internal: Kubernetes ClusterIP services + DNS (service.namespace.svc.cluster.local). For external: AWS ALB Ingress Controller with host-based and path-based routing. All services share one ALB using group.name annotation. The ALB routes directly to pod IPs (target-type: ip) — no extra NodePort hop."

---

### 3. Event-Driven Architectures

**Q: How would you design an event-driven architecture for a trading system?**

> "For a trading system, I'd use:
> - SNS for broadcasting events (order placed, trade executed) to multiple subscribers
> - SQS for decoupled async processing (settlement, notifications) with dead-letter queues for failed messages
> - EventBridge for rule-based routing (if trade > $1M → trigger compliance check)
> - Lambda for lightweight event handlers (validation, enrichment)
> - Kinesis for real-time streaming of market data (high throughput, ordered)
>
> Key principle: services communicate via events, not direct API calls. If the payment service is down, orders still queue in SQS and process when it recovers."

**Q: How do you ensure message reliability in SQS?**

> "Visibility timeout so messages aren't processed twice. Dead-letter queue (DLQ) after 3 failed attempts — alerts on DLQ depth. FIFO queues for ordered processing (important for trading). CloudWatch alarm on ApproximateNumberOfMessagesVisible — if queue depth grows, something is stuck."

**Q: Kinesis vs SQS — when to use which?**

> "Kinesis: real-time streaming, multiple consumers reading same data, ordered by partition key. Use for market data feeds, click streams, log aggregation.
>
> SQS: point-to-point async processing, exactly-once delivery (FIFO), auto-scaling consumers. Use for background jobs, order processing, notifications.
>
> For trading: Kinesis for market data (high throughput, multiple consumers), SQS for order processing (exactly-once matters)."

---

### 4. Security & Networking

**Q: How do you implement IAM best practices?**

> "Least privilege everywhere. IRSA for pods (no shared node credentials). OIDC for CI/CD (no stored access keys). IAM policies scoped to specific resources, not `*`. Service control policies at org level. Regular access reviews. Secrets in AWS Secrets Manager, not Kubernetes Secrets."

**Q: How do you secure a VPC for a trading platform?**

> "Three-tier architecture:
> - Public subnets: only ALBs (internet-facing)
> - Private subnets: application pods (no direct internet, egress via NAT)
> - Database subnets: isolated, no internet access, only reachable from private subnets
>
> Security Groups act as pod-level firewalls. NACLs as subnet-level backup. VPC Flow Logs for audit. For high-security: AWS PrivateLink for inter-service communication without traversing the internet."

**Q: How would you connect on-premises systems to AWS?**

> "AWS Direct Connect for dedicated, low-latency connection (important for trading — can't have internet jitter). Transit Gateway to connect multiple VPCs and on-prem networks centrally. VPN as a backup path if Direct Connect has issues. Route53 private hosted zones for internal DNS resolution across environments."

---

### 5. Monitoring & Incident Response

**Q: How do you set up monitoring for a trading platform?**

> "Four layers:
> 1. Infrastructure: CloudWatch + node-exporter (CPU, memory, disk, network)
> 2. Kubernetes: kube-state-metrics (pod status, deployments, HPA)
> 3. Application: custom Prometheus metrics (/metrics endpoint) — request latency, error rate, order count
> 4. Business: trade volume per second, order fill rate, P&L calculations
>
> Grafana dashboards for visualization. Alertmanager for routing alerts to PagerDuty/Slack based on severity. X-Ray for distributed tracing across microservices."

**Q: How do you handle incident response?**

> "Structured process:
> 1. DETECT: Grafana alert fires (p99 latency > 2s for 5 min)
> 2. TRIAGE: Check dashboards → identify affected service → assess impact
> 3. MITIGATE: Rollback deployment or scale up (restore service first)
> 4. DEBUG: Logs (CloudWatch/Loki) + traces (X-Ray) + metrics correlation
> 5. FIX: Deploy permanent fix through pipeline
> 6. REVIEW: Blameless post-mortem, action items, improve monitoring gaps"

**Q: How do you implement DR for a trading system?**

> "RTO < 5 min, RPO < 1 min for critical trading systems:
> - RDS Multi-AZ: automatic failover in 30 seconds
> - EKS across 2+ AZs: if one AZ dies, pods reschedule
> - S3 Cross-Region Replication for trade data
> - Route53 health checks + failover routing to DR region
> - Regular DR drills (chaos engineering) to validate recovery
> - AWS Backup for automated snapshots of all data stores"

---

### 6. Collaboration & Process

**Q: How do you work with development teams?**

> "I provide self-service platforms: developers push code, CI/CD handles everything. I maintain the Helm charts, pipeline templates, and monitoring stack. When they need a new service, I provide a template (Dockerfile, Helm chart, ArgoCD app). I also built an AI monitoring agent that lets developers ask 'what's wrong with my service?' in plain English — reduces MTTR and support tickets."

**Q: How do you approach architecture reviews?**

> "I review for: single points of failure, security gaps (public endpoints, overly broad IAM), cost optimization opportunities, and operational readiness (monitoring, runbooks, rollback plan). I push for Infrastructure as Code — if it's not in Git, it doesn't exist."

---

## Scenario Questions They Might Ask

**Q: A trading service is experiencing latency spikes during market open. How do you troubleshoot?**

> "1. Check if it's infrastructure: CloudWatch CPU/memory on nodes — are we hitting limits?
> 2. Check pod level: kubectl top pods — is the service saturated?
> 3. Check database: RDS Performance Insights — slow queries during peak?
> 4. Check upstream: Is it a dependency (market data feed) or the service itself?
> 5. Check HPA: Did it scale up fast enough? Pre-scale before market open using scheduled scaling.
> 6. Fix: If DB — add read replicas + connection pooling. If compute — increase HPA maxReplicas + faster scale-up (30s instead of 5 min)."

**Q: How would you migrate a monolithic trading system to microservices on EKS?**

> "Strangler Fig pattern:
> 1. Identify bounded contexts (order, execution, settlement, risk)
> 2. Extract one service at a time (start with least coupled — notifications)
> 3. Run both old and new in parallel, route traffic gradually
> 4. Use SQS/SNS between new services (loose coupling)
> 5. Each service gets its own namespace, Helm chart, pipeline
> 6. ArgoCD manages all deployments — one Git repo per service or monorepo with paths-filter"

**Q: Your EKS cluster needs to handle 10x traffic during market events. How?**

> "1. HPA: auto-scale pods based on custom metrics (requests/sec, queue depth)
> 2. Cluster Autoscaler: adds nodes when pods are Pending
> 3. Predictive scaling: pre-warm 30 min before market open (scheduled HPA)
> 4. ALB: auto-scales automatically (AWS-managed)
> 5. Kinesis: increase shard count for market data streams
> 6. DynamoDB: on-demand mode (auto-scales read/write capacity)
> 7. Test: load test with realistic peak traffic before going live"

---

## Things to Highlight About Your Project

| What You Did | Why It Matters to IC Markets |
|---|---|
| EKS with IRSA (zero static credentials) | Security-first for financial systems |
| Shared ALB with host-based routing | Cost-efficient, production-grade networking |
| GitHub Actions OIDC (no stored secrets) | Meets compliance requirements |
| ArgoCD GitOps (self-healing, audit trail) | Every change tracked in Git — audit-friendly |
| Argo Rollouts canary | Risk-free deployments for trading services |
| Prometheus + Grafana monitoring | Real-time observability for SLA tracking |
| Terraform modules (VPC, EKS, IAM) | Reproducible, multi-environment infrastructure |
| AI monitoring agent (MCP) | Innovative approach to reducing MTTR |

---

## Questions to Ask Them

1. "What does your current deployment pipeline look like — Jenkins, CodePipeline, or something else?"
2. "Are you running EKS or ECS for your trading workloads?"
3. "How do you handle market-hours scaling — predictive or reactive?"
4. "What's your current DR strategy — multi-region active-active or active-passive?"
5. "How do you manage secrets for trading services — Vault, Secrets Manager, or parameter store?"
6. "What's the latency requirement for your order execution path?"

---

## Key Buzzwords for This Role

Event-driven, low-latency, fault-tolerant, multi-AZ, IRSA, GitOps, canary deployment, Infrastructure as Code, least privilege, observability, SRE, error budgets, chaos engineering, disaster recovery, compliance, real-time processing, pub/sub, stream processing
