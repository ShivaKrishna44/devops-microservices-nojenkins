# LTM Systems Manager — Interview Preparation

---

## Q1: Cross-Account & Multi-Region Patching with AWS SSM

**Simple answer:**

> "I use SSM Patch Manager with a multi-account setup. The management account defines patch baselines and maintenance windows. Target accounts are registered via AWS Organizations. SSM uses resource data sync to aggregate compliance data across all accounts into one central S3 bucket."

**How it works:**

```
Management Account (central):
  ├── Define Patch Baselines (what to patch — critical + security)
  ├── Create Maintenance Windows (when — Sunday 2am)
  └── Resource Data Sync → aggregates compliance across accounts

Target Accounts (clients):
  ├── SSM Agent installed on all EC2 instances (pre-installed on Amazon Linux)
  ├── Instances registered via IAM role with SSM permissions
  └── Patch compliance reported back to management account
```

**Steps:**
1. Enable AWS Organizations + delegated admin for SSM
2. Create a patch baseline: auto-approve critical patches after 7 days
3. Create a maintenance window: Sunday 2-4am
4. Define targets: tag-based (`PatchGroup: production`)
5. Run `AWS-RunPatchBaseline` document across all accounts
6. Resource Data Sync pushes compliance to central S3

**Multi-region:** Use CloudFormation StackSets to deploy SSM configuration across all regions.

---

## Q2: SSM Parameter Store vs AWS Secrets Manager

| Feature | Parameter Store | Secrets Manager |
|---|---|---|
| Purpose | Configuration data + simple secrets | Secrets that need rotation |
| Cost | Free (standard), $0.05/advanced | $0.40/secret/month |
| Rotation | ❌ Manual | ✅ Automatic (Lambda-based) |
| Max size | 8KB (advanced) | 64KB |
| Encryption | Optional KMS | Always KMS |
| Cross-account | ❌ No | ✅ Resource policies |
| Versioning | ✅ Yes | ✅ Yes |
| Hierarchy | `/app/prod/db_host` (path-based) | Flat names |

**When to use which:**

| Use Case | Choice |
|---|---|
| Database passwords (need rotation) | Secrets Manager |
| API keys from third parties | Secrets Manager |
| Application config (DB_HOST, PORT) | Parameter Store |
| Feature flags | Parameter Store |
| License keys | Secrets Manager |
| Non-sensitive config (region, cluster name) | Parameter Store (free) |

**Interview answer:**

> "Parameter Store is for configuration — things like endpoints, feature flags, non-sensitive settings. It's free and supports hierarchical paths. Secrets Manager is for credentials that need automatic rotation — database passwords, API keys. It costs more but handles rotation via Lambda automatically. In my project, I use Parameter Store to store VPC IDs and subnet IDs for cross-stack reference, and Secrets Manager for database credentials."

---

## Q3: High CPU on Production Server — RCA with AWS Native Tools

**Immediate steps:**

```bash
# Step 1: Check CloudWatch — when did it start?
# Look at CPUUtilization metric — correlate with deployment time

# Step 2: CloudWatch → Contributor Insights
# Shows which PROCESS is consuming CPU

# Step 3: SSM Session Manager — log into the server (no SSH key needed)
aws ssm start-session --target i-0abc123def

# Step 4: Inside the server:
top                    # Which process is eating CPU?
ps aux --sort=-%cpu    # Top CPU consumers
strace -p <PID>        # What syscalls is it making?
journalctl --since "1 hour ago"  # Recent logs
```

**AWS tools for RCA:**

| Tool | What It Shows |
|---|---|
| CloudWatch Metrics | CPU timeline — when did spike start? |
| CloudWatch Logs Insights | Application errors correlated with spike |
| CloudTrail | Was there a recent deployment/config change? |
| SSM Session Manager | Live shell access to investigate |
| X-Ray | If it's a latency issue — trace the slow request |
| Performance Insights (RDS) | If DB is the bottleneck |

**Common causes:**

| Cause | How to Identify |
|---|---|
| Stuck process / infinite loop | `top` shows 100% CPU on one process |
| Memory leak → swap thrashing | `free -h` shows 0 free + high swap usage |
| Sudden traffic spike | CloudWatch NetworkIn/RequestCount spiked |
| Bad deployment (new code) | Correlate with CloudTrail/CodeDeploy timestamp |
| Cron job running | Check `crontab -l`, time matches CPU spike |

---

## Q4: Traffic Flow — Private Subnet to Internet (Outbound)

```
Application (in Private Subnet, no public IP)
    ↓
Route Table: 0.0.0.0/0 → NAT Gateway
    ↓
NAT Gateway (lives in Public Subnet, has Elastic IP)
    ↓
Route Table: 0.0.0.0/0 → Internet Gateway
    ↓
Internet Gateway → Internet (apt update, pip install, etc.)
    ↓
Response comes back same path (NAT translates back to private IP)
```

**Key points:**
- Private subnet has NO internet gateway route — only NAT
- NAT Gateway translates private IP → its own public Elastic IP
- Inbound from internet CANNOT reach private subnet (one-way)
- NAT is per-AZ (one per AZ for redundancy)
- Cost: ~$32/month per NAT Gateway + data processing charges

**Interview answer:**

> "Instances in private subnets don't have public IPs. When they need internet (for updates or API calls), traffic goes through a NAT Gateway in the public subnet. The NAT translates the private IP to its Elastic IP for outbound requests. Responses come back through the NAT. Inbound traffic from the internet cannot reach private instances — it's one-way. I deploy one NAT per AZ to avoid cross-AZ single points of failure."

---

## Q5: Restrict API Actions / Regions Across Client Portfolio

**Tool: Service Control Policies (SCPs) in AWS Organizations**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyNonApprovedRegions",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["us-east-1", "eu-west-1"]
        }
      }
    },
    {
      "Sid": "DenyExpensiveActions",
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances",
        "rds:CreateDBInstance"
      ],
      "Resource": "*",
      "Condition": {
        "ForAnyValue:StringNotEquals": {
          "ec2:InstanceType": ["t3.small", "t3.medium", "t3.large"]
        }
      }
    }
  ]
}
```

**How it works:**
- SCPs attach to Organizational Units (OUs) or individual accounts
- Even account admins can't bypass SCPs — they're guardrails
- Stack them: OU-level SCP + account-level SCP

**Interview answer:**

> "I use Service Control Policies at the Organizations level. SCPs act as permission boundaries — even if an IAM user has AdministratorAccess, the SCP can deny them. I restrict allowed regions (only us-east-1 and eu-west-1), block expensive instance types, and prevent disabling CloudTrail. SCPs are applied to OUs so all client accounts inherit the restrictions."

---

## Q6: Connect Multiple VPCs Across Business Units

**Options:**

| Method | Use Case | Scale |
|---|---|---|
| VPC Peering | 2-3 VPCs, simple | Small |
| Transit Gateway | 10+ VPCs, centralized | Large |
| PrivateLink | Expose one service to another VPC | Service-specific |

**Transit Gateway (recommended for multi-BU):**

```
Business Unit A (VPC-A) ─┐
Business Unit B (VPC-B) ─┼─── Transit Gateway ─── On-Premises (Direct Connect)
Business Unit C (VPC-C) ─┘
Shared Services (VPC-D) ─┘
```

**Key points:**
- Hub-and-spoke model — all VPCs connect to one TGW
- Route tables control who can talk to whom
- Can connect to on-prem via Direct Connect or VPN
- Cross-region: use TGW peering between regions

**Interview answer:**

> "For multiple VPCs across business units, I use AWS Transit Gateway as a central hub. Each VPC attaches to the TGW, and route tables control which VPCs can communicate. This avoids the n-squared peering problem. For isolation, I use separate TGW route tables per business unit — so finance can't reach engineering directly. On-prem connects via Direct Connect to the TGW."

---

## Q7: Terraform Plan vs Apply + State Locking

**Difference:**

| | `terraform plan` | `terraform apply` |
|---|---|---|
| What it does | Dry run — shows changes WITHOUT making them | Actually creates/modifies/destroys resources |
| Safe? | Yes — read-only | No — modifies real infrastructure |
| Workflow | Always run plan FIRST | Only run after reviewing plan output |

**Preventing simultaneous modifications:**

```
Engineer A runs terraform apply → acquires DynamoDB lock ✅
Engineer B runs terraform apply → gets "Error: state locked" ❌

# Lock stored in DynamoDB:
{
  "LockID": "s3://state-bucket/dev/terraform.tfstate",
  "Info": "Operation: apply, Who: engineer-a, Created: 2026-07-08T10:30:00Z"
}
```

**Backend config:**
```hcl
backend "s3" {
  bucket         = "terraform-state-bucket"
  key            = "dev/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-state-lock"  # ← prevents race conditions
  encrypt        = true
}
```

---

## Q8: Python Boto3 Script — Clean Up Unattached EBS Volumes

```python
import boto3

def cleanup_unattached_volumes():
    """
    Finds and deletes EBS volumes that are not attached to any EC2 instance.
    Saves cost by removing forgotten/orphaned volumes.
    """
    ec2 = boto3.client('ec2', region_name='us-east-1')
    
    # Find all volumes in 'available' state (not attached)
    response = ec2.describe_volumes(
        Filters=[{'Name': 'status', 'Values': ['available']}]
    )
    
    unattached = response['Volumes']
    print(f"Found {len(unattached)} unattached volumes")
    
    for vol in unattached:
        vol_id = vol['VolumeId']
        size = vol['Size']
        created = vol['CreateTime'].strftime('%Y-%m-%d')
        
        print(f"  Deleting: {vol_id} ({size}GB, created {created})")
        
        # Safety: only delete if older than 7 days
        from datetime import datetime, timezone
        age = (datetime.now(timezone.utc) - vol['CreateTime']).days
        if age > 7:
            ec2.delete_volume(VolumeId=vol_id)
            print(f"    ✅ Deleted")
        else:
            print(f"    ⏭️  Skipped (only {age} days old)")

if __name__ == "__main__":
    cleanup_unattached_volumes()
```

**Run as Lambda on a schedule (weekly):**
- EventBridge rule: `rate(7 days)` → triggers this Lambda
- Reports orphaned volumes via SNS notification
- Saves ~$10/month per forgotten 100GB volume

---

## Q9: EKS App Unreachable — Debugging Checklist

```
Step 1: Are pods running?
  kubectl get pods -n <namespace>
  → If CrashLoopBackOff: check logs (kubectl logs --previous)
  → If Pending: check describe pod (resource/scheduling issue)

Step 2: Is the service routing to pods?
  kubectl get endpoints <service-name> -n <namespace>
  → If empty: selector mismatch

Step 3: Is ingress configured?
  kubectl describe ingress -n <namespace>
  → Check host, paths, backend service name

Step 4: Is ALB healthy?
  aws elbv2 describe-target-health --target-group-arn <arn>
  → If unhealthy: health check path/port wrong

Step 5: Does DNS resolve?
  nslookup <domain>
  → If NXDOMAIN: Route53 CNAME missing

Step 6: Network/Security Group?
  → ALB SG allows inbound 443
  → Node SG allows ALB → pod port
```

---

## Q10: CodePipeline Failure at Staging — Automated Rollback

**Design:**

```
CodePipeline:
  Source → Build → Deploy to Staging → Manual Approval → Deploy to Prod
                          ↓
                  CloudWatch Alarm (5xx > 5% for 2 min)
                          ↓
                  Lambda: Rollback to previous TaskDef/Deployment
                          ↓
                  SNS → Slack notification "Rollback triggered"
```

**How to implement:**
1. Deploy action uses CodeDeploy with `BlueGreenDeployment`
2. After staging deploy → run automated tests (Lambda or CodeBuild)
3. If tests fail or alarm fires → CodeDeploy auto-rolls back
4. Approval gate blocks prod until staging is verified

```yaml
# CodeDeploy AppSpec with automatic rollback:
Hooks:
  AfterAllowTestTraffic:
    - location: test-staging.sh
      timeout: 300
# If test fails → deployment fails → CodeDeploy rolls back
```

---

## Q11: Client Requests Oversized Instance — Budget Guardrails

**Approach:**

1. **SCP (prevent at org level):**
```json
{
  "Effect": "Deny",
  "Action": "ec2:RunInstances",
  "Condition": {
    "ForAnyValue:StringNotLike": {
      "ec2:InstanceType": ["t3.*", "m5.large", "m5.xlarge"]
    }
  }
}
```

2. **AWS Budgets alert:**
- Set budget threshold per account
- Alert at 80% → SNS → team lead
- Action at 100% → auto-deny EC2 launches via IAM policy

3. **Service Catalog:**
- Pre-approved products only (t3.medium, t3.large)
- Client selects from dropdown — can't type custom values
- Terraform modules with `validation` blocks:

```hcl
variable "instance_type" {
  validation {
    condition     = contains(["t3.small", "t3.medium", "t3.large"], var.instance_type)
    error_message = "Instance type not approved. Contact cloud team."
  }
}
```

**Interview answer:**

> "I handle this at multiple layers: SCPs block unapproved instance types at the org level — even admins can't bypass it. AWS Budgets alerts the team when spending approaches limits. And for self-service, I use Service Catalog or Terraform modules with validation constraints. The client can only select from pre-approved sizes. If they need an exception, it goes through a change request with cost justification."
