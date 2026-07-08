# Disaster Recovery Plan — Warm Standby

---

## Strategy Overview

| Metric | Target |
|---|---|
| Strategy | Warm Standby |
| Primary Region | us-east-1 |
| DR Region | us-west-2 |
| RTO (Recovery Time) | < 15 minutes |
| RPO (Data Loss) | < 5 minutes |
| Monthly DR Cost | ~$120 additional |

---

## Architecture

```
                    Route53 (Failover Routing)
                         │
            ┌────────────┴────────────┐
            │                         │
     PRIMARY (us-east-1)       DR (us-west-2)
     ┌──────────────┐         ┌──────────────┐
     │ EKS Cluster  │         │ EKS Cluster  │
     │ 2× t3.medium │         │ 1× t3.small  │ ← Warm Standby
     │ Full workload │         │ Minimal      │
     │              │         │              │
     │ ECR ─────────────────→ ECR (replicated)
     │ S3  ─────────────────→ S3 (CRR)
     └──────────────┘         └──────────────┘
            ▲                         ▲
      Health Check               Scales up on
      every 10 sec               failover
```

---

## What's Running in Each Region

| Component         | Primary (us-east-1)   | DR (us-west-2)                  |
|-------------------|-----------------------|---------------------------------|
| EKS Cluster       | ✅ Full (2 nodes)     | ✅ Minimal (1 small node)      |
| Microservices     | ✅ 3 services running | ❌ Not deployed until failover |
| ArgoCD            | ✅ Active             | ❌ Deployed on failover        |
| Monitoring        | ✅ Full stack         | ❌ Not needed in standby       |
| ALB               | ✅ Active             | ❌ Created on failover         |
| ECR Images        | ✅ Source             | ✅ Auto-replicated             |
| S3 Data           | ✅ Source             | ✅ Cross-Region Replication    |

---

## Automated Components (Always Running)

These run continuously without intervention:
1. **ECR Replication** — every image pushed to us-east-1 auto-replicates to us-west-2
2. **Route53 Health Check** — pings `app.vosukula.online/order` every 10 seconds
3. **S3 CRR** — any data written to S3 replicates to DR region

---

## Failover Procedure (When Primary Dies)

### Automatic (Route53)
```
1. Health check fails 3 consecutive times (30 seconds)
2. Route53 automatically switches DNS to DR region
3. Users are now routed to DR ALB
```

### Manual Steps (< 15 minutes total)

```bash
# Step 1: Scale up DR EKS nodes (2 min)
aws eks update-nodegroup-config \
  --cluster-name expense-dev-dr \
  --nodegroup-name dr_nodes \
  --scaling-config minSize=2,maxSize=5,desiredSize=2 \
  --region us-west-2

# Step 2: Configure kubectl for DR cluster (30 sec)
aws eks update-kubeconfig --name expense-dev-dr --region us-west-2

# Step 3: Deploy services to DR using ArgoCD or Helm (5 min)
# Option A: Install ArgoCD + apply apps (full GitOps)
bash scripts/04-install-argocd.sh
kubectl apply -f kubernetes/argocd/apps/

# Option B: Direct Helm deploy (faster)
helm upgrade --install order-service ./charts/microservice \
  -f charts/microservice/values-order.yaml -n order-service --create-namespace
helm upgrade --install payment-service ./charts/microservice \
  -f charts/microservice/values-payment.yaml -n payment-service --create-namespace
helm upgrade --install user-service ./charts/microservice \
  -f charts/microservice/values-user.yaml -n user-service --create-namespace

# Step 4: Install ALB Controller (2 min)
bash scripts/02-install-alb-controller.sh

# Step 5: Apply ingresses (1 min)
kubectl apply -f kubernetes/ingress/

# Step 6: Verify (1 min)
kubectl get pods -A
curl https://app.vosukula.online/order
```

**Total time: ~12 minutes**

---

## Failback Procedure (Return to Primary)

After primary region is restored:

```bash
# 1. Verify primary is healthy
aws eks update-kubeconfig --name expense-dev --region us-east-1
kubectl get nodes
kubectl get pods -A

# 2. Ensure data sync is complete
# ECR: images already in both regions
# S3: verify CRR caught up

# 3. Update Route53 — switch back to primary
# Route53 auto-switches when primary health check passes again
# OR manually: set primary record weight back

# 4. Scale down DR
aws eks update-nodegroup-config \
  --cluster-name expense-dev-dr \
  --nodegroup-name dr_nodes \
  --scaling-config minSize=1,maxSize=5,desiredSize=1 \
  --region us-west-2

# 5. Remove DR workloads (optional — save cost)
helm uninstall order-service -n order-service
helm uninstall payment-service -n payment-service
helm uninstall user-service -n user-service
```

---

## Testing DR (Chaos Engineering)

### Monthly DR Drill
```bash
# Simulate primary failure
# 1. Scale primary nodes to 0
aws eks update-nodegroup-config \
  --cluster-name expense-dev \
  --nodegroup-name expense-dev-nodes \
  --scaling-config minSize=0,maxSize=0,desiredSize=0 \
  --region us-east-1

# 2. Watch Route53 failover (should happen in 30 sec)
dig app.vosukula.online

# 3. Run failover procedure above

# 4. Verify DR serves traffic
curl https://app.vosukula.online/order

# 5. Restore primary + failback
aws eks update-nodegroup-config \
  --cluster-name expense-dev \
  --nodegroup-name expense-dev-nodes \
  --scaling-config minSize=2,maxSize=5,desiredSize=2 \
  --region us-east-1
```

---

## Terraform Code

DR infrastructure is defined in `Terraform/dr-region.tf`:
- DR VPC (10.1.0.0/16) in us-west-2
- DR EKS cluster (1× t3.small, warm standby)
- ECR replication rules (auto-replicate images)
- Route53 health checks + failover records

**To deploy DR infra:**
```bash
cd Terraform
terraform apply -var-file=tfvars/dev/dev.tfvars -target=module.dr_vpc -target=module.dr_eks
```

**To destroy DR infra (save cost):**
```bash
terraform destroy -var-file=tfvars/dev/dev.tfvars -target=module.dr_vpc -target=module.dr_eks
```

---

## Cost Comparison

| Setup | Monthly Cost |
|---|---|
| Primary only (current) | ~$183 |
| Primary + Warm Standby DR | ~$303 (+$120) |
| Primary + Active-Active DR | ~$368 (+$185) |

---

## Why Warm Standby (Not Active-Active)

| Factor | Active-Active | Warm Standby (chosen) |
|---|---|---|
| Cost | 2x primary | 1.6x primary |
| RTO | < 1 minute | < 15 minutes |
| Complexity | High (data sync both ways) | Medium (one-way replication) |
| Data conflicts | Possible (split-brain) | None (single writer) |
| Operational burden | High | Low |

For our microservices with 99.9% SLA (43 min/month allowed downtime), 15 minutes RTO is more than sufficient. Active-Active adds complexity without business justification.

---

## Interview Answer

> "I implemented Warm Standby DR across two AWS regions. Primary runs in us-east-1 with full EKS cluster. DR in us-west-2 has a minimal EKS cluster (1 small node) with ECR images auto-replicated. Route53 health checks ping the primary every 10 seconds — if 3 checks fail, DNS automatically fails over to DR. On failover, we scale up the DR nodes, deploy services via Helm (images already in ECR), and apply ingresses. Total recovery: under 15 minutes. We chose this over Active-Active because it meets our RTO requirement at 60% less cost and avoids split-brain data issues."
