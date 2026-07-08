# Highly Available AWS Architecture

I designed a highly available AWS architecture with a target of 99.99% availability and disaster recovery in under 15 minutes.

The goal wasn't to use every AWS service. It was to build an architecture that balances reliability, security, scalability, and cost.

- **Primary Region:** us-east-1
- **DR Region:** us-west-2 (Warm Standby)

---

## Recovery Targets

| Metric | Target |
|---|---|
| Availability | 99.99% |
| RTO (Recovery Time Objective) | < 15 minutes |
| RPO (Recovery Point Objective) | < 5 minutes |

---

## Architecture Highlights

### Edge Layer

| Component | Purpose |
|---|---|
| Route 53 Failover | DNS-based health checks + automatic failover to DR |
| CloudFront CDN | Cache static content at edge, reduce latency globally |
| AWS WAF | Block malicious requests before they reach the VPC |
| AWS Certificate Manager | Wildcard HTTPS certs, auto-renewed |

All traffic is protected before reaching the VPC.

---

### Networking

| Component | Detail |
|---|---|
| Availability Zones | 3 AZs for maximum redundancy |
| Subnets | Public, Private App, and Private DB subnets per AZ |
| NAT Gateways | One per AZ — eliminates a hidden single point of failure |

---

### Compute

| Component | Detail |
|---|---|
| Load Balancer | Multi-AZ Application Load Balancer (ALB) |
| Auto Scaling Group | Min: 2 / Desired: 3 / Max: 10 |
| Security | ALB accepts traffic only from CloudFront (prevents direct internet access) |

---

### Data

| Component | Purpose |
|---|---|
| Amazon RDS MySQL | Multi-AZ (automatic failover in 30 seconds) |
| Amazon ElastiCache Redis | Session store + caching (reduces DB load) |
| Amazon S3 | Cross-Region Replication to DR region |

Keeping EC2 instances stateless allows seamless horizontal scaling.

---

### Security

| Service | What It Does |
|---|---|
| AWS WAF | Blocks SQL injection, XSS, bad bots |
| Security Groups | Instance-level firewall (least privilege) |
| AWS KMS | Encryption at rest for all data stores |
| AWS Secrets Manager | Rotate credentials automatically |
| AWS GuardDuty | Threat detection (anomalous API calls, crypto mining) |
| AWS Config | Compliance rules (detect misconfigurations) |
| AWS CloudTrail | Audit log of every API call |

---

### Disaster Recovery

A **Warm Standby** architecture provides an excellent balance between resilience and cost.

**Failover flow:**
```
1. Route 53 health check detects primary region failure
    ↓
2. DNS automatically fails over to DR region (us-west-2)
    ↓
3. RDS Read Replica promoted to primary (< 5 min)
    ↓
4. ASG in DR scales up from warm standby to full capacity
    ↓
5. Service restored in under 15 minutes
```

**Why Warm Standby over Active-Active:**

| Strategy | Cost | Complexity | RTO |
|---|---|---|---|
| Backup & Restore | Low | Low | Hours |
| Pilot Light | Low-Medium | Medium | 15-30 min |
| **Warm Standby (chosen)** | **Medium** | **Medium** | **< 15 min** |
| Active-Active | High | High | < 1 min |

Instead of choosing Active-Active because it looks impressive, I selected the architecture that best meets the business requirements — reliable recovery without doubling infrastructure cost.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
│                                 │                                            │
│                    ┌────────────┴────────────┐                               │
│                    │     Route 53 (Failover)  │                              │
│                    └────────────┬────────────┘                               │
│                                 │                                            │
│                    ┌────────────┴────────────┐                               │
│                    │   CloudFront CDN + WAF   │                              │
│                    └────────────┬────────────┘                               │
│                                 │                                            │
│  ┌──────────────────────────────┴──────────────────────────────────────┐    │
│  │                    PRIMARY REGION (us-east-1)                         │    │
│  │                                                                      │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │              VPC (3 Availability Zones)                      │    │    │
│  │  │                                                             │    │    │
│  │  │  Public Subnets:   [ALB] [NAT-1] [NAT-2] [NAT-3]          │    │    │
│  │  │                                                             │    │    │
│  │  │  Private Subnets:  [EC2] [EC2] [EC2]  ← ASG (2-10)        │    │    │
│  │  │                                                             │    │    │
│  │  │  DB Subnets:       [RDS Primary] [RDS Standby]             │    │    │
│  │  │                    [ElastiCache Redis]                      │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                                                                      │    │
│  │  S3 ──── Cross-Region Replication ────→ S3 (us-west-2)              │    │
│  │  RDS ──── Async Replication ──────────→ RDS Read Replica (us-west-2)│    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │                    DR REGION (us-west-2) — Warm Standby               │    │
│  │                                                                      │    │
│  │  [ALB] → [ASG: min 1, scales up on failover]                        │    │
│  │  [RDS Read Replica → promotes to Primary]                            │    │
│  │  [S3 replica — already synced]                                       │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Design Decisions

| Decision | Reasoning |
|---|---|
| 3 AZs (not 2) | Survives 1 AZ failure with capacity to spare |
| NAT per AZ (not shared) | Shared NAT = single point of failure for all private subnets |
| CloudFront → ALB (not direct internet) | Hides origin, absorbs DDoS, caches static content |
| Stateless EC2 | Allows instant horizontal scaling, no session affinity needed |
| RDS Multi-AZ + Read Replica in DR | 30-second failover within region, < 15 min cross-region |
| Warm Standby (not Active-Active) | 50% less cost, meets RTO requirement, simpler operations |
| S3 CRR | Data available in DR without manual intervention |


---

## Simple Interview Version (How to Explain)

### "Explain your HA architecture" (2-minute answer):

> "I designed a highly available architecture on AWS targeting 99.99% uptime with a 15-minute recovery time.
>
> Traffic flow is simple: Users hit Route53 → CloudFront (caching + WAF protection) → ALB → EC2 instances behind an Auto Scaling Group.
>
> For reliability: Everything runs across 3 Availability Zones. If one AZ dies, the other two handle the load automatically. Each AZ has its own NAT Gateway — because a shared NAT is a hidden single point of failure that most people miss.
>
> Compute is stateless: EC2 instances don't store session data — Redis handles that. So Auto Scaling can add or remove instances anytime without losing user sessions.
>
> Database: RDS Multi-AZ gives us 30-second automatic failover within the region. We also have a Read Replica in us-west-2 for DR.
>
> Disaster Recovery: I chose Warm Standby — not Active-Active. A minimal setup runs in us-west-2 at all times. If Route53 detects primary region failure, it switches DNS to DR. RDS replica promotes to primary. ASG scales up. Full recovery under 15 minutes.
>
> Why not Active-Active? It doubles cost and complexity. Our RTO requirement was 15 minutes — Warm Standby meets that at half the price. You pick the strategy that fits the business requirement, not the one that looks most impressive on a diagram."

---

### Follow-up: "What about security?"

> "Every layer has protection. WAF blocks malicious traffic before it reaches the VPC. CloudFront hides the origin — ALB only accepts traffic from CloudFront, not direct internet. Inside the VPC: Security Groups for instance-level firewall, KMS for encryption at rest, Secrets Manager for credentials with automatic rotation. GuardDuty for threat detection, CloudTrail for audit trail."

---

### Follow-up: "Why 3 AZs not 2?"

> "With 2 AZs, if one fails you're running at 50% capacity — might not handle the full load. With 3 AZs, losing one still leaves you at 66% — enough headroom to serve all traffic while the failed AZ recovers."

---

### Follow-up: "How does the failover work exactly?"

> "Route53 has health checks pinging the ALB every 10 seconds. If 3 consecutive checks fail, it marks the primary as unhealthy. DNS automatically resolves to the DR region ALB. The DR region's ASG scales from warm standby (1 instance) to full capacity (3 instances). RDS Read Replica is promoted to standalone primary. Total time: under 15 minutes. S3 data is already replicated — no action needed."
