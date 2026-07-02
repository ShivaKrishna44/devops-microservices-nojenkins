# DevOps Microservices Platform — Complete Deployment Guide

## GitHub Actions CI + ArgoCD GitOps CD — No Jenkins

---

## Architecture Overview

```
┌──────────────────────────────────────────────────-────────────────────────┐
│                                                                           │
│  Developer → git push → GitHub                                            │
│                              ↓                                            │
│  ┌───────────────────────────────────────────────────-─┐                  │
│  │  GitHub Actions (CI)                                │                  │
│  │  ├── Detect changed service (paths-filter)          │                  │
│  │  ├── Build Docker image                             │                  │
│  │  ├── Push to AWS ECR                                │                  │
│  │  └── Update image tag in Helm values → git push     │                  │
│  └───────────────────────────────────────────────────-─┘                  │
│                              ↓                                            │
│  ┌──────────────────────────────────────────────────-──┐                  │
│  │  ArgoCD (CD — GitOps, runs inside EKS)              │                  │
│  │  ├── Polls GitHub every 3 min                       │                  │
│  │  ├── Detects image tag change in Helm values        │                  │
│  │  └── Auto-syncs deployment to EKS                   │                  │
│  └─────────────────────────────────────────────────-───┘                  │
│                              ↓                                            │
│  ┌──────────────────────────────────────-──────────────┐                  │
│  │  AWS EKS Cluster (expense-dev)                      │                  │
│  │  ├── order-service   (namespace: order-service)     │                  │
│  │  ├── payment-service (namespace: payment-service)   │                  │
│  │  ├── user-service    (namespace: user-service)      │                  │
│  │  ├── monitoring      (Prometheus + Grafana)         │                  │
│  │  ├── sonarqube       (Code quality)                 │                  │
│  │  └── argo-rollouts   (Canary/Blue-Green)            │                  │
│  └──────────────────────────────────────────────-──────┘                  │
│                                                                           │
│  Infrastructure managed by: Terraform                                     │
│  DNS: Route53 → ALB → EKS pods                                            │
│  Certs: ACM wildcard (*.vosukula.online)                                  │
│                                                                           │
└──────────────────────────────────────────────────────────────────-────────┘
```

---

## Platform Components

| Component          | Tool                       | URL                             |
|--------------------|----------------------------|---------------------------------|
| Infrastructure     | Terraform + AWS EKS        |  —                              |
| CI (Build)         | GitHub Actions             | GitHub → Actions tab            |
| CD (Deploy)        | ArgoCD (GitOps)            | https://argocd.vosukula.online  |
| Monitoring         | Prometheus + Grafana       | https://grafana.vosukula.online |
| Code Quality       | SonarQube                  | https://sonar.vosukula.online   |
| App                | Python Flask microservices | https://app.vosukula.online     |
| Registry           | AWS ECR                    | us-east-1                       |
| Progressive Delivery| Argo Rollouts             | Canary/Blue-Green               |

**Key Config:**
- AWS Account: `589389425618`
- Region: `us-east-1`
- EKS Cluster: `expense-dev`
- Domain: `vosukula.online`
- ACM Wildcard Cert: `arn:aws:acm:us-east-1:589389425618:certificate/483235ba-eb66-4a81-b2ab-6244c3f2a2d6`

---

## Full Setup — Step by Step

### Step 1: Terraform Infrastructure (15 min)

```bash
cd Terraform
terraform init -backend-config=tfvars/dev/backend.tfvars
terraform plan -var-file=tfvars/dev/dev.tfvars
terraform apply -var-file=tfvars/dev/dev.tfvars
```

**What this creates:**
- VPC with public/private/database subnets
- EKS cluster `expense-dev` (Kubernetes 1.33)
- ECR repositories: order-service, payment-service, user-service
- IAM roles: node group, EBS CSI, ALB controller
- S3 backend + DynamoDB state locking

---

### Step 2: Configure kubectl (2 min)

```bash
bash scripts/01-install-tools.sh
```

Or manually:
```bash
aws eks update-kubeconfig --name expense-dev --region us-east-1
kubectl get nodes
# Should show 2 nodes in Ready state
```

---

### Step 3: Install AWS Load Balancer Controller (3 min)

```bash
bash scripts/02-install-alb-controller.sh
```

Verify:
```bash
kubectl get pods -n kube-system | grep aws-load-balancer
# Should show 2 pods Running
```

---

### Step 4: Install ArgoCD (3 min)

```bash
bash scripts/04-install-argocd.sh
```

**What this does:**
- Creates `argocd` namespace
- Installs ArgoCD using `--server-side` (required for large CRDs)
- Applies ArgoCD ingress

**Get admin password:**
```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

**Access:** https://argocd.vosukula.online  
**Username:** `admin`  
**Password:** from command above

---

### Step 5: Install Monitoring — Prometheus + Grafana (5 min)

```bash
# Create namespace + secret FIRST
kubectl create namespace monitoring
kubectl create secret generic grafana-admin-secret \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=YOUR_PASSWORD \
  -n monitoring

# Install
bash scripts/05-install-monitoring.sh

# Apply ingress
kubectl apply -f kubernetes/ingress/grafana-ingress.yaml
```

**Access:** https://grafana.vosukula.online  
**Username:** `admin`  
**Password:** what you set above

**Recommended Dashboards (import by ID):**
| ID      | Name                          |
|---------|-------------------------------|
| `15760` | Kubernetes Cluster Monitoring |
| `13770` | Kubernetes Pod Metrics        |
| `12006` | Kubernetes Deployment Metrics |

---

### Step 6: Install SonarQube — Optional (5 min)

```bash
bash scripts/06-install-sonarqube.sh
kubectl apply -f kubernetes/ingress/sonarqube-ingress.yaml
```

**Access:** https://sonar.vosukula.online  
**Default login:** `admin` / `admin`

---

### Step 7: Install Argo Rollouts (2 min)

```bash
bash scripts/07-install-argo-rollouts.sh
kubectl get pods -n argo-rollouts
```

Enables canary and blue-green deployment strategies.

---

### Step 8: Configure GitHub Actions (5 min)

#### 8a. Add GitHub Secrets

Go to: **Repository → Settings → Secrets and variables → Actions → New repository secret**

| Secret Name             | Value               |
|-------------------------|---------------------|
| `AWS_ACCESS_KEY_ID`     | Your IAM access key |
| `AWS_SECRET_ACCESS_KEY` | Your IAM secret key |

#### 8b. Apply ArgoCD Applications

```bash
kubectl apply -f kubernetes/argocd/apps/
```

Verify:
```bash
kubectl get applications -n argocd
# NAME              SYNC STATUS   HEALTH STATUS
# order-service     Synced        Healthy
# payment-service   Synced        Healthy
# user-service      Synced        Healthy
```

#### 8c. Trigger First Build

**Option A — Push code changes:**
```bash
# Edit any service file
echo "# trigger" >> app/order-service/app.py
git add . && git commit -m "trigger first build" && git push
```

**Option B — Manual trigger:**
- Go to: GitHub → Actions → "CI/CD Pipeline" → Run workflow
- Select service name + tag → Run

---

## How the CI/CD Pipeline Works

### Pipeline File: `.github/workflows/ci-cd.yml`

**Triggers:**
| Trigger             | When                                     |
|---------------------|------------------------------------------|
| `push` to main      | When files in `app/` or `charts/` change |
| `pull_request`      | Validates build on PR (no deploy)        |
| `workflow_dispatch` | Manual — pick service + tag from UI      |

**Auto-detect (smart builds):**
- Uses `dorny/paths-filter` to detect which service changed
- Only builds the service that was modified (not all 3)
- Example: change `app/order-service/app.py` → only order-service builds

**Pipeline stages:**
```
1. Detect Changes → which service folder changed?
2. Configure AWS Credentials → from GitHub Secrets
3. Login to ECR → temporary Docker auth token
4. Build Docker Image → docker build ./app/<service>/
5. Push to ECR → <account>.dkr.ecr.us-east-1.amazonaws.com/<service>:<tag>
6. Update Helm Values → sed to update image tag in values file
7. Commit & Push → triggers ArgoCD sync
```

---

## How ArgoCD GitOps Works

**ArgoCD Application config (`kubernetes/argocd/apps/order-service.yaml`):**
```yaml
spec:
  source:
    repoURL: https://github.com/ShivaKrishna44/devops-microservices-platform.git
    path: charts/microservice
    helm:
      valueFiles:
        - values-order.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: order-service
  syncPolicy:
    automated:
      prune: true       # Delete resources removed from Git
      selfHeal: true    # Revert manual cluster changes
    syncOptions:
      - CreateNamespace=true
```

**What happens:**
1. GitHub Actions updates `charts/microservice/values-order.yaml` with new tag
2. ArgoCD polls Git every 3 minutes
3. Detects the tag changed → triggers sync
4. Applies Helm chart with new values → new pods with new image
5. Old pods terminated → zero-downtime rolling update

**Self-healing:** If someone manually changes something in the cluster, ArgoCD reverts it to match Git.

---

## Helm Chart Structure

```
charts/microservice/
├── Chart.yaml              ← Chart metadata
├── values.yaml             ← Default values (shared)
├── values-order.yaml       ← Order service overrides (image tag here)
├── values-payment.yaml     ← Payment service overrides
├── values-user.yaml        ← User service overrides
└── templates/
    ├── deployment.yaml     ← Pod spec
    ├── service.yaml        ← ClusterIP service
    ├── hpa.yaml            ← Horizontal Pod Autoscaler
    ├── rollout.yaml        ← Argo Rollout (canary/blue-green)
    ├── canary-service.yaml ← Canary traffic service
    └── preview-service.yaml← Blue-green preview service
```

**Values file example (`values-order.yaml`):**
```yaml
image:
  repository: 589389425618.dkr.ecr.us-east-1.amazonaws.com/order-service
  tag: "latest12"
```

GitHub Actions updates `tag` → ArgoCD deploys new version.

---

## Canary & Blue-Green Deployments (Argo Rollouts)

### Enable Canary for a Service

Edit `charts/microservice/values-order.yaml`:
```yaml
rollout:
  enabled: true
  strategy: canary
  steps:
    - setWeight: 20     # Send 20% traffic to new version
    - pause: {duration: 60s}
    - setWeight: 50
    - pause: {duration: 60s}
    - setWeight: 100    # Full rollout
```

### Monitor Rollout
```bash
kubectl argo rollouts get rollout order-service -n order-service --watch
```

### Promote (skip pause)
```bash
kubectl argo rollouts promote order-service -n order-service
```

### Abort (instant rollback)
```bash
kubectl argo rollouts abort order-service -n order-service
```

---

## Microservice Endpoints

| Service          | Endpoint          | Returns                                               |
|------------------|-------------------|-------------------------------------------------------|
| order-service    | `GET /`           | `{"service": "order-service", "status": "running"}`   |
| order-service    | `GET /orders`     | List of orders                                        |
| payment-service  | `GET /`           | `{"service": "payment-service", "status": "running"}` |
| payment-service  | `GET /payments`   | List of payments                                      |
| user-service     | `GET /`           | `{"service": "user-service", "status": "running"}`    |
| user-service     | `GET /users`      | List of users                                         |

**Test via ingress:**
```bash
curl https://app.vosukula.online/order
curl https://app.vosukula.online/payment
curl https://app.vosukula.online/user
```

---

## Monitoring & Observability

### Grafana Dashboards
- Cluster overview: CPU, memory, pod status
- Per-service: latency, error rate, request volume
- Node metrics: disk, network

### Prometheus Queries (useful)
```promql
# Pod restarts in last hour
increase(kube_pod_container_status_restarts_total[1h]) > 3

# CPU usage by namespace
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)

# Memory usage
container_memory_usage_bytes / container_spec_memory_limit_bytes * 100

# HTTP error rate
rate(http_requests_total{status=~"5.."}[5m])
```

### Alert Examples
| Alert                     | PromQL                                                                  |
|---------------------------|-------------------------------------------------------------------------|
| Pod restarts > 3 in 5 min | `increase(kube_pod_container_status_restarts_total[5m]) > 3`            |
| Node CPU > 80%            | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80` |
| Pod not ready             | `kube_pod_status_ready{condition="false"} == 1`                         |

---

## Route53 DNS Records

| Subdomain                | Points To                                    |
|--------------------------|----------------------------------------------|
| `argocd.vosukula.online` | ALB from `kubectl get ingress -n argocd`     |
| `grafana.vosukula.online`| ALB from `kubectl get ingress -n monitoring` |
| `sonar.vosukula.online`  | ALB from `kubectl get ingress -n sonarqube`  |
| `app.vosukula.online`    | ALB from `kubectl get ingress` (default ns)  |

All use CNAME records pointing to ALB DNS name.

---

## Useful Commands

```bash
# Cluster health
kubectl get nodes
kubectl get pods -A
kubectl get pods -A | grep -v Running

# ArgoCD
kubectl get applications -n argocd
kubectl -n argocd patch app order-service --type merge -p '{"operation":{"sync":{}}}'

# Deployments
kubectl get deployments -A
kubectl rollout undo deployment/order-service -n order-service

# Helm
helm list -A
helm history order-service -n order-service

# GitHub Actions (gh CLI)
gh run list --limit 5
gh run view <run-id> --log

# ECR
aws ecr describe-images --repository-name order-service --query 'imageDetails | sort_by(@, &imagePushedAt) | [-3:].[imageTags[0],imagePushedAt]'
```

---

## Teardown (Destroy Everything)

```bash
# 1. Delete ArgoCD apps
kubectl delete -f kubernetes/argocd/apps/

# 2. Uninstall Helm releases
helm uninstall monitoring -n monitoring
helm uninstall sonarqube -n sonarqube

# 3. Delete ArgoCD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Delete Argo Rollouts
kubectl delete -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml -n argo-rollouts

# 5. Delete ALB Controller
helm uninstall aws-load-balancer-controller -n kube-system

# 6. Delete namespaces
kubectl delete namespace monitoring sonarqube argocd argo-rollouts order-service payment-service user-service

# 7. Destroy Terraform infrastructure
cd Terraform
terraform destroy -var-file=tfvars/dev/dev.tfvars
```

⚠️ `terraform destroy` is permanent — deletes EKS, VPC, ECR, everything.

---

## Comparison: This Project vs Jenkins Version

| Aspect            | Jenkins Version                          | This Version (GitHub Actions) |
|-------------------|------------------------------------------|-------------------------------|
| CI Tool           | Jenkins on EKS (Helm)                    | GitHub Actions (cloud-hosted) |
| CI Infrastructure | EC2 agent + EKS pod + plugins            | Zero (GitHub manages runners) |
| Setup time        | 2+ hours                                 | 5 minutes (workflow file + secrets) |
| Maintenance       | Plugin updates, disk space, agent health | None                          |
| Cost              | EC2 24/7 + EKS pod resources             | Free (public) / 2000 min/month (private) |
| CD Tool           | Same — ArgoCD                            | Same — ArgoCD                 |
| Monitoring        | Same — Prometheus + Grafana              | Same — Prometheus + Grafana   |
| Infrastructure    | Same — Terraform + EKS                   | Same — Terraform + EKS        |
| Rollouts          | Same — Argo Rollouts                     | Same — Argo Rollouts          |

**What was removed:**
- Jenkinsfile
- Jenkins Helm chart + values
- Jenkins agent EC2 setup
- Jenkins ingress
- Jenkins namespace + secrets
- Jenkins plugins management

**What replaced it:**
- `.github/workflows/ci-cd.yml` (single file, ~150 lines)

---

## Troubleshooting

| Issue | Fix |
|---|---|
| GitHub Actions: "permission denied" on ECR | Check `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets in GitHub |
| ArgoCD shows OutOfSync | `kubectl apply -f kubernetes/argocd/apps/` or manual sync in UI |
| ArgoCD can't reach Git | Verify repo URL in Application CRD is correct |
| ALB not provisioning | Check ALB controller pods: `kubectl get pods -n kube-system` |
| Ingress has no ADDRESS | Wait 3-5 min for ALB provisioning, check ingress events |
| DNS not resolving | Add CNAME in Route53 pointing to ALB DNS |
| Pod ImagePullBackOff | Check image tag exists in ECR: `aws ecr describe-images --repo <name>` |
| Pod CrashLoopBackOff | Check logs: `kubectl logs <pod> -n <ns> --previous` |
| Grafana secret missing | Create `grafana-admin-secret` BEFORE installing monitoring |

---

## Project File Structure

```
.
├── .github/
│   └── workflows/
│       └── ci-cd.yml              ← GitHub Actions CI/CD pipeline
├── app/
│   ├── order-service/
│   │   ├── app.py                 ← Flask app
│   │   ├── Dockerfile             ← Container build
│   │   ├── requirements.txt       ← Python deps
│   │   └── sonar-project.properties
│   ├── payment-service/           ← Same structure
│   └── user-service/              ← Same structure
├── charts/
│   └── microservice/
│       ├── Chart.yaml
│       ├── values.yaml            ← Default values
│       ├── values-order.yaml      ← Order image tag (updated by CI)
│       ├── values-payment.yaml    ← Payment image tag
│       ├── values-user.yaml       ← User image tag
│       └── templates/             ← K8s manifests (deployment, service, hpa, rollout)
├── kubernetes/
│   ├── argocd/
│   │   ├── apps/                  ← ArgoCD Application CRDs (3 services)
│   │   └── argocd-ingress.yaml
│   ├── ingress/
│   │   ├── app-ingress.yaml       ← Routes /order, /payment, /user
│   │   ├── grafana-ingress.yaml
│   │   └── sonarqube-ingress.yaml
│   ├── monitoring/
│   │   └── grafana-values.yaml
│   └── sonarqube/
│       └── sonarqube-values.yaml
├── scripts/
│   ├── 01-install-tools.sh
│   ├── 02-install-alb-controller.sh
│   ├── 04-install-argocd.sh
│   ├── 05-install-monitoring.sh
│   ├── 06-install-sonarqube.sh
│   └── 07-install-argo-rollouts.sh
├── Terraform/
│   ├── provider.tf, backend.tf
│   ├── vpc.tf, eks.tf, ecr.tf
│   ├── iam-irsa.tf, iam-nodegroup.tf
│   ├── variables.tf, local.tf, output.tf
│   └── tfvars/dev/, tfvars/prod/
├── mcp-server/                    ← AI monitoring agent
│   ├── mcp_server.py
│   └── requirements.txt
├── DEPLOYMENT-GUIDE.md            ← This file
└── README.md                      ← Project overview
```
