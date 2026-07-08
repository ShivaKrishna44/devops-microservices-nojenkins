# DevOps Debugging Interview Q&A — 19 Scenarios

---

## Part 1: Kubernetes & EKS Troubleshooting

---

### Q1: New pods stuck in Pending after deployment

**First command:**
```bash
kubectl describe pod <pod-name> -n <namespace>
# Look at Events section at bottom
```

**Common causes:**

| Cause | What You See | Fix |
|---|---|---|
| Not enough CPU/memory | `Insufficient cpu` or `Insufficient memory` | Scale nodes or reduce resource requests |
| Node selector mismatch | `didn't match node selector` | Fix nodeSelector/affinity in pod spec |
| PVC can't bind | `unbound PersistentVolumeClaim` | Check PVC is in same AZ as node |

**My real example:** We hit this when HPA set minReplicas=2 for 3 services on 2 small nodes. 6 pods couldn't fit. Fix: reduced to minReplicas=1.

---

### Q2: App inaccessible from internet (EKS + ALB healthy)

**Debug top-down (follow the traffic path):**

```bash
# 1. DNS resolves?
nslookup app.vosukula.online

# 2. ALB targets healthy?
aws elbv2 describe-target-health --target-group-arn <arn>

# 3. Ingress rules correct?
kubectl describe ingress <name> -n <namespace>

# 4. Service has endpoints?
kubectl get endpoints <service-name> -n <namespace>
# If empty → selector labels don't match pods
```

**My real example:** App returned "Backend service does not exist" because ingress was in `default` namespace but services were in their own namespaces. Fix: per-namespace ingresses with shared ALB group.

---

### Q3: EKS node goes NotReady

**First action:** SSH via SSM Session Manager and check system:

```bash
# Check kubelet
systemctl status kubelet
journalctl -u kubelet --since "5 min ago"

# Check resources
free -h          # memory
df -h            # disk
top              # CPU
```

**Common causes:**

| Cause | Fix |
|---|---|
| Kubelet crashed | `systemctl restart kubelet` |
| Out of memory (OOM) | Kernel killed processes. Reduce pod memory or add nodes |
| Disk full | `docker system prune -af` or expand EBS volume |
| Network lost | Check security groups, VPC routes |

---

### Q4: Today's pods crashing, yesterday's pods fine

**Isolate what changed:**

```bash
# 1. Which pods are failing?
kubectl get pods --sort-by='.metadata.creationTimestamp' -n <namespace>

# 2. What error?
kubectl logs <pod-name> --previous

# 3. What changed in Git?
git log --since="24 hours ago" --oneline
```

**Usually it's:** new image tag with a bug, config change, or dependency that broke overnight.

---

### Q5: Nodes full + traffic spike

**Two levels to fix:**

| Level | Tool | What It Does |
|---|---|---|
| Pod level | HPA | Adds more pods when CPU > 70% |
| Node level | Cluster Autoscaler / Karpenter | Adds more EC2 nodes when pods are Pending |

```yaml
# HPA config
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilization: 70
```

Together: HPA creates pods → pods go Pending → Autoscaler adds nodes → pods schedule.

---

### Q6: Latency increased but pods look healthy — is it the DB?

**Shift focus from compute to database:**

| Tool | What to Check |
|---|---|
| RDS Performance Insights | Slow queries, lock waits |
| CloudWatch `DBConnections` | Connection pool exhausted? |
| CloudWatch `DiskQueueDepth` | Storage I/O maxed out? |
| `ReadIOPS` / `WriteIOPS` | Hitting IOPS limit? |

**Fix:** Add read replicas, connection pooling (RDS Proxy), or optimize slow queries with indexes.

---

### Q7: Pod making unauthorized external API calls

**Don't check app logs — check network:**

```bash
# 1. VPC Flow Logs — filter by pod IP
# Shows destination IPs the pod is calling

# 2. CloudTrail — check what AWS APIs the pod's IAM role called
aws cloudtrail lookup-events --lookup-attributes AttributeKey=Username,AttributeValue=<role-name>

# 3. GuardDuty — automated threat detection
# Flags crypto mining, unusual API patterns, DNS exfiltration
```

**Immediate action:** Network Policy to block egress from that pod, then investigate.

---

### Q8: EBS volume won't mount (StatefulSet)

```bash
kubectl describe pvc <pvc-name> -n <namespace>
kubectl get volumeattachments
```

**Common causes:**

| Cause | Fix |
|---|---|
| AZ mismatch | EBS is in us-east-1a but pod scheduled to 1b. Use `topologySpreadConstraints` |
| Volume still attached to old node | Wait for detach or force-detach via AWS CLI |
| EBS CSI IAM missing | Check IRSA role has `ec2:AttachVolume` permission |

**My real example:** Prometheus pod stuck Pending because its PVC was bound to Node 1's AZ, but Node 1 was full. Couldn't schedule on Node 2 (wrong AZ for the volume).

---

## Part 2: Terraform & State Management

---

### Q9: Someone deletes an ALB from AWS Console. Next terraform plan?

**What happens:**
- State says ALB exists
- AWS says ALB doesn't exist
- `terraform plan` detects drift: "will be created"
- `terraform apply` recreates it

**No manual intervention needed** — Terraform is self-healing for this case.

---

### Q10: State file deleted + no S3 versioning

**DO NOT run terraform apply** — it'll try to create everything again (name conflicts).

**Recovery:**
```bash
# Import each existing resource back into state
terraform import aws_vpc.main vpc-abc123
terraform import module.eks.aws_eks_cluster.this expense-dev
terraform import aws_ecr_repository.order order-service
# ... repeat for each resource
```

**Prevention:** Always enable S3 versioning + DynamoDB locking.

---

### Q11: Terraform apply crashes after creating VPC but before EKS

**Good news:** State already tracked the VPC.

```bash
# 1. Check what was created
terraform state list
# Shows: aws_vpc.main ✓ (tracked)

# 2. Fix the error (usually IAM permission or service limit)

# 3. Re-run apply — it skips VPC, continues with EKS
terraform apply
```

Terraform is idempotent — re-running is always safe.

---

### Q12: Two engineers run terraform apply at same time

**DynamoDB lock prevents this:**
- First engineer acquires lock → apply runs
- Second engineer gets: `Error: Error locking state`

**If lock is stuck (crashed process):**
```bash
terraform force-unlock <LOCK_ID>
# Only after confirming no one is actually running
```

---

### Q13: Updating shared VPC module used by 15 environments

**Safe approach:**
1. Module lives in its own Git repo with version tags
2. Update module → create new tag (v2.0.0)
3. Upgrade one environment at a time:

```hcl
# dev (upgrade first)
source = "git::https://github.com/org/vpc-module.git?ref=v2.0.0"

# prod (upgrade last, after dev is validated)
source = "git::https://github.com/org/vpc-module.git?ref=v1.0.0"  # stays on old until proven
```

Never upgrade all 15 at once.

---

## Part 3: GitOps, Security & Architecture

---

### Q14: Someone manually scales replicas from 3 to 20. ArgoCD response?

**With `selfHeal: true`:**
- ArgoCD detects drift within 3 minutes
- Automatically reverts to Git-declared value (3 replicas)
- No human action needed

**Without selfHeal:**
- Shows OutOfSync in UI
- Waits for manual sync

**My setup:** `selfHeal: true` + `prune: true` — ArgoCD is the enforcer.

---

### Q15: Bad deployment breaks production. How to rollback with ArgoCD?

**Wrong way:** `kubectl rollout undo` — ArgoCD will override it in 3 minutes.

**Right way (GitOps):**
```bash
# Revert the bad commit
git revert <broken-commit>
git push origin main

# ArgoCD detects → syncs → deploys previous version
```

Clean audit trail. ArgoCD handles the rest.

---

### Q16: Why IRSA over static access keys?

| | Static Keys | IRSA |
|---|---|---|
| Lifetime | Permanent until rotated | Auto-expires every hour |
| Scope | Shared by entire node | Per-pod, per-service |
| If leaked | Full AWS access forever | Expires in 60 min |
| Storage | Somewhere on disk/env var | No secrets stored, injected via OIDC |

**IRSA flow:** Pod → K8s ServiceAccount → OIDC token → AWS STS → temporary credentials (1 hour).

---

### Q17: DB password rotated without app downtime

**Architecture:**
```
AWS Secrets Manager (stores password)
    ↓ Lambda rotates every 30 days
Secrets Store CSI Driver (mounts into pod filesystem)
    ↓ enableSecretRotation: true
App watches file change → reloads DB connection pool
    ↓
Zero downtime. No pod restart needed.
```

---

### Q18: Entire AWS region goes dark. Recovery in 30 min?

**Warm Standby architecture:**

```
1. Route53 health check detects primary failure (30 sec)
2. DNS fails over to DR region automatically
3. DR EKS nodes scale up (2 min)
4. Deploy services via Helm/ArgoCD (5 min)
5. RDS Read Replica promotes to primary (5 min)
6. Full service restored (< 15 min total)
```

ECR images already replicated. S3 data already synced via CRR.

---

### Q19: EKS version upgrade with zero downtime

```bash
# Step 1: Upgrade control plane (AWS handles it, no downtime)
# Terraform: update cluster_version = "1.33"
terraform apply

# Step 2: Create NEW node group with new version (Blue-Green)
# Add new node group in Terraform, keep old one

# Step 3: Drain old nodes (respects PDBs)
kubectl drain <old-node> --delete-emptydir-data --ignore-daemonsets

# Step 4: Pods reschedule to new nodes automatically

# Step 5: Delete old node group
# Remove from Terraform, apply
```

Never upgrade nodes in-place. Always Blue-Green with drain.

---

## Key Interview Principle

Structure every answer as:

```
1. FIRST COMMAND (what you'd type immediately)
2. COMMON CAUSES (2-3 most likely)
3. FIX (specific, actionable)
4. REAL EXAMPLE (from your project)
```

This shows you've actually debugged these issues — not just read about them.
