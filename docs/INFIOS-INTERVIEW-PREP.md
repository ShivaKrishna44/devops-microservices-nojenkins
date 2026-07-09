# Infios — Cloud Operations Manager Interview Prep

**Company:** Infios (Supply chain logistics — WM & TM platforms)
**Role:** Cloud Operations Manager
**Focus:** Team leadership + Kubernetes SaaS operations + SLA-driven incident management

---

## HR Round — Behavioral Questions

### "Tell me about yourself"

> "I'm a Senior DevOps Engineer with 8+ years of experience managing cloud infrastructure and leading operations for production Kubernetes platforms. I've managed EKS clusters running microservices with full CI/CD automation, monitoring, and GitOps deployments. I also have experience mentoring team members and driving SLA improvements through automation. I'm looking for a leadership role where I can combine my technical depth with team management — which is exactly what this Cloud Operations Manager position offers."

---

### "Why Infios?"

> "Two reasons: First, the supply chain space is where technology has massive real-world impact — improving how goods move globally is meaningful work. Second, this role combines what I'm best at — Kubernetes operations and infrastructure automation — with team leadership, which is where I want to grow. I'm excited about managing a team that keeps SaaS platforms running reliably."

---

### "Describe your management style"

> "I lead by example and focus on enablement. I ensure my team has clear runbooks, proper monitoring, and automation so they can handle incidents confidently without needing me on every call. I do regular 1:1s to understand blockers, and I invest in documentation and cross-training so knowledge isn't siloed. During incidents, I'm hands-on — I don't just delegate, I troubleshoot alongside the team."

---

### "Tell me about a time you handled a critical incident"

> "Our EKS cluster had nodes going NotReady during peak hours. I led the investigation — SSM'd into the node, found the kubelet was OOMKilled because monitoring stack was consuming too much memory. I scaled down non-critical components immediately (alertmanager), which freed resources and restored the node. Then I implemented a permanent fix — reduced HPA minReplicas and added proper resource quotas per namespace. Documented everything so the team could handle it independently next time."

---

### "How do you handle team performance issues?"

> "I focus on clarity first. If someone is struggling, I check: do they have clear expectations? Do they have the right tools and knowledge? Most 'performance issues' are actually knowledge gaps or unclear priorities. I address it with specific examples, provide resources/pairing, and set a clear improvement timeline. I've found that investing in documentation and runbooks prevents most performance issues — people perform well when they know exactly what to do."

---

### "How do you prioritize incidents?"

> "Severity-based triage:
> - P1 (production down): All hands, immediate response, restore first, debug later
> - P2 (degraded): Assigned to on-call, 1-hour response SLA
> - P3 (non-critical): Queue for next business day
>
> I use the impact + urgency matrix. A single user affected is P3. All users affected is P1. I also ensure the team documents every P1/P2 with a post-mortem — not for blame, but to prevent recurrence."

---

## Technical Round — Expected Questions & Answers

---

### Q1: "You manage Kubernetes SaaS apps. A pod is CrashLoopBackOff. Walk me through debugging."

> "Step 1: `kubectl logs <pod> --previous` — see why it crashed.
> Step 2: `kubectl describe pod` — check Events (image pull, OOM, missing config).
> Step 3: Common causes:
> - Exit code 137 → OOMKilled (increase memory limit)
> - Exit code 1 → app error (check logs for stack trace)
> - Missing ConfigMap/Secret → mount failed
>
> Step 4: If it's environment-specific (works in staging, fails in prod), check: env vars, secrets, config differences between environments."

---

### Q2: "How do you manage Helm-templated Kubernetes environments?"

> "I use a shared Helm chart with per-environment values files:
> ```
> charts/microservice/
> ├── values.yaml          ← defaults
> ├── values-dev.yaml      ← dev overrides (1 replica, small resources)
> ├── values-staging.yaml  ← staging
> └── values-prod.yaml     ← prod (3 replicas, larger resources)
> ```
>
> ArgoCD deploys each environment by referencing the appropriate values file. Changes go through Git PR → review → merge → ArgoCD auto-syncs. I never do `helm install` directly on production — everything goes through GitOps."

---

### Q3: "An SLA breach is imminent. Response time is degraded. What do you do?"

> "Immediate triage:
> 1. Is it one service or all? → Check ingress/ALB health
> 2. Are pods healthy? → `kubectl top pods` (CPU/memory saturation)
> 3. Is it the database? → Check connection pool, slow queries
> 4. Is it a recent deployment? → Correlate with last deploy time → rollback if needed
>
> Quick mitigations while debugging:
> - Scale up replicas (more pods = more capacity)
> - Rollback if recently deployed
> - Check if external dependency is slow (third-party API, DNS)
>
> After resolution: Post-mortem + action items to prevent recurrence."

---

### Q4: "How do you use Terraform in operations?"

> "I manage all infrastructure as code — VPCs, EKS clusters, IAM roles, ECR repos. Key practices:
> - Remote state in S3 with DynamoDB locking (prevent conflicts)
> - Modular design (vpc module, eks module — reusable across environments)
> - Plan → PR review → Apply (never apply without peer review for prod)
> - Drift detection: scheduled `terraform plan -refresh-only` alerts on manual changes
>
> For this role, I'd use Terraform to manage both OCI and AWS resources — the provider model supports both clouds."

---

### Q5: "How do you handle automation to improve SLAs?"

> "Examples of automation I've built:
> - Auto-scaling: HPA scales pods on CPU/custom metrics
> - Self-healing: ArgoCD reverts manual cluster changes (prevents drift)
> - Automated deployments: GitHub Actions → build → push → GitOps deploy
> - Alert-based remediation: CloudWatch alarm → Lambda → restart unhealthy service
> - Runbook automation: Ansible playbooks for common ops tasks (agent setup, cluster bootstrap)
>
> The goal: reduce MTTR (Mean Time To Resolve) by removing human steps from the critical path."

---

### Q6: "Tell me about your experience with performance troubleshooting"

> "I follow a layered approach:
> - Infrastructure: Node CPU/memory (Prometheus/Grafana node-exporter)
> - Kubernetes: Pod resource usage, HPA status, scheduling issues
> - Application: Request latency (p50/p95/p99), error rates, throughput
> - Database: Connection pool exhaustion, slow queries, IOPS limits
>
> Tools I use: Prometheus for metrics, Grafana for visualization, `kubectl top` for quick checks, and application-level tracing for distributed systems.
>
> Real example: Latency spiked but pods looked healthy. Turned out the DB connection pool was exhausted — 50 connections max, 50 pods each holding one = no connections left for new requests. Fixed by adding connection pooling (PgBouncer) and reducing connection hold time."

---

### Q7: "This role involves OCI (Oracle Cloud). What's your experience?"

> "My primary cloud is AWS, but the operational patterns transfer directly:
> - OCI OKE (Kubernetes) = AWS EKS — same kubectl, same Helm, same monitoring
> - OCI OCIR (Container Registry) = AWS ECR
> - OCI Compute = AWS EC2
> - OCI VCN = AWS VPC
>
> Kubernetes is cloud-agnostic — my Helm charts, ArgoCD workflows, and monitoring stack work identically on OKE. I'm confident I can ramp up on OCI-specific services quickly because the underlying concepts (networking, IAM, storage) are the same."

---

### Q8: "How would you train and onboard a new team member?"

> "Week 1: Access setup + read documentation (deployment guides, runbooks, architecture)
> Week 2: Shadow on-call — observe incident handling, ask questions
> Week 3: Handle P3 tickets with pairing — learn the codebase
> Week 4: Solo on-call for non-critical hours — mentor available for escalation
>
> Key enablers:
> - Comprehensive runbooks (every common issue documented with exact commands)
> - Grafana dashboards bookmarked (they can see system health instantly)
> - Slack channel with historical incident discussions (searchable knowledge base)
>
> My philosophy: if a new team member can't resolve a P2 incident within their first month using our documentation alone, the documentation is the problem — not the person."

---

### Q9: "IIS/Tomcat troubleshooting — have you worked with Java apps?"

> "Yes. For Java/Tomcat specifically:
> - Thread dumps: `jstack <PID>` — find deadlocks or stuck threads
> - Heap dumps: `jmap -dump:format=b,file=heap.bin <PID>` — memory leak analysis
> - GC logs: check for long GC pauses (stop-the-world events cause latency spikes)
> - Tomcat manager: `/manager/status` — check active sessions, thread pool utilization
> - JMX metrics: expose via Prometheus JMX exporter for Grafana dashboards
>
> Common issue: Java apps consume max heap on startup, leaving no memory for other pods on the same node. Fix: set proper `-Xmx` and Kubernetes memory limits to match."

---

### Q10: "How do you manage deployments across geographically dispersed systems?"

> "GitOps makes this straightforward:
> - One Git repo = source of truth for all regions
> - ArgoCD in each cluster watches the same repo
> - Deploy to one region first (canary), validate, then promote to others
> - Time-zone aware maintenance windows (don't deploy during client peak hours)
>
> For rollback: revert the Git commit → all regions auto-sync to previous version simultaneously.
>
> Key consideration: database migrations must be backward-compatible — the new code must work with both old and new schema during the rolling deployment across regions."

---

## Questions to Ask Them

1. "What does the current on-call rotation look like for the operations team?"
2. "What's the ratio of reactive incidents vs proactive improvement work?"
3. "Are you currently on OCI, AWS, or both? Any plans to consolidate or expand?"
4. "What's the team size I'd be managing, and what's their current skill level?"
5. "What's the biggest operational challenge you face today with the WM/TM platforms?"
6. "How do you measure SLA compliance — what tooling is in place?"

---

## Key Points to Emphasize

| Their Need | Your Experience |
|---|---|
| Kubernetes SME | You manage EKS clusters with Helm, HPA, ArgoCD, Argo Rollouts |
| Team leadership | You've documented runbooks, mentored through incidents, built onboarding |
| SLA-focused | You've set up monitoring + alerts + automated remediation |
| Terraform | You write modular Terraform for VPC, EKS, IAM — all from scratch |
| Incident management | You have 25+ real incidents documented with root cause + fix |
| Multi-cloud | AWS primary, but K8s skills transfer to OCI OKE directly |
| Automation | Ansible, Python, GitHub Actions, GitOps — all hands-on |
| Java app management | Can troubleshoot Tomcat, JVM issues, thread/heap analysis |
