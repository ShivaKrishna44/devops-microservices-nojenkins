# Shared ALB Strategy — Cost Optimization Guide

How to use ONE ALB for all services instead of multiple ALBs.

---

## The Problem: Multiple ALBs = Expensive

**Without shared ALB (bad):**
```
argocd-ingress     → creates ALB #1  ($16/month)
grafana-ingress    → creates ALB #2  ($16/month)
sonarqube-ingress  → creates ALB #3  ($16/month)
app-ingress        → creates ALB #4  ($16/month)
                                      ─────────
                     Total:           $64/month + data charges
```

**With shared ALB (good):**
```
argocd-ingress     ─┐
grafana-ingress     ├─→ ONE shared ALB  ($16/month)
sonarqube-ingress   │
app-ingress        ─┘
                     Total:           $16/month + data charges
```

**Savings:** $48/month = ~$576/year for one cluster.

---

## How It Works: `group.name` Annotation

The AWS Load Balancer Controller merges multiple Ingress resources into ONE ALB when they share the same `group.name`:

```yaml
# All these become ONE ALB:
annotations:
  alb.ingress.kubernetes.io/group.name: "vosukula-shared-alb"
```

The ALB routes traffic by **host header**:
```
Request comes in → ALB checks Host header:
  argocd.vosukula.online  → routes to argocd-server:443
  grafana.vosukula.online → routes to monitoring-grafana:80
  sonar.vosukula.online   → routes to sonarqube:9000
  app.vosukula.online     → routes by path (/order, /payment, /user)
```

---

## Implementation in Our Project

### Before (Multiple ALBs)

```yaml
# argocd-ingress.yaml — NO group.name → gets its own ALB
metadata:
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing

# grafana-ingress.yaml — NO group.name → gets its own ALB
metadata:
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing

# app-ingress.yaml — different group → gets another ALB
metadata:
  annotations:
    alb.ingress.kubernetes.io/group.name: "app-shared-alb"
```

Result: 3 ALBs created. 3x the cost.

---

### After (One Shared ALB)

```yaml
# argocd-ingress.yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/group.name: "vosukula-shared-alb"  # ← SAME

# grafana-ingress.yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/group.name: "vosukula-shared-alb"  # ← SAME

# sonarqube-ingress.yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/group.name: "vosukula-shared-alb"  # ← SAME

# app-ingress.yaml (all 3 services)
metadata:
  annotations:
    alb.ingress.kubernetes.io/group.name: "vosukula-shared-alb"  # ← SAME
```

Result: 1 ALB. All routes merged. One DNS entry covers everything.

---

## How the Shared ALB Routes Traffic

```
┌──────────────────────────────────────────────────────────────────┐
│              ONE ALB (vosukula-shared-alb)                         │
│                                                                    │
│  Listener: HTTPS:443 (ACM wildcard cert *.vosukula.online)        │
│                                                                    │
│  Rules (auto-created by ALB controller):                           │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ Host: argocd.vosukula.online  → Target: argocd-server:443  │   │
│  │ Host: grafana.vosukula.online → Target: grafana:80          │   │
│  │ Host: sonar.vosukula.online   → Target: sonarqube:9000      │   │
│  │ Host: app.vosukula.online                                   │   │
│  │   Path: /order   → Target: order-service:5000               │   │
│  │   Path: /payment → Target: payment-service:5000             │   │
│  │   Path: /user    → Target: user-service:5000                │   │
│  │   Path: /        → Target: order-service:5000 (default)     │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

---

## Route53 Setup (One ALB = One CNAME Target)

All subdomains point to the SAME ALB DNS name:

| Record | Type | Value |
|---|---|---|
| `argocd.vosukula.online` | CNAME | `k8s-vosukulasharedalb-xxx.us-east-1.elb.amazonaws.com` |
| `grafana.vosukula.online` | CNAME | `k8s-vosukulasharedalb-xxx.us-east-1.elb.amazonaws.com` |
| `sonar.vosukula.online` | CNAME | `k8s-vosukulasharedalb-xxx.us-east-1.elb.amazonaws.com` |
| `app.vosukula.online` | CNAME | `k8s-vosukulasharedalb-xxx.us-east-1.elb.amazonaws.com` |

All same value! The ALB distinguishes requests by the `Host` header.

---

## Key Annotations Explained

```yaml
annotations:
  # REQUIRED — groups ingresses into one ALB
  alb.ingress.kubernetes.io/group.name: "vosukula-shared-alb"

  # Internet-facing (public) vs internal (private)
  alb.ingress.kubernetes.io/scheme: internet-facing

  # Route to pod IPs directly (faster) vs node ports
  alb.ingress.kubernetes.io/target-type: ip

  # Enable both HTTP and HTTPS listeners
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'

  # Auto-redirect HTTP → HTTPS
  alb.ingress.kubernetes.io/ssl-redirect: '443'

  # ACM certificate for HTTPS (wildcard covers all subdomains)
  alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."

  # Health check path for this backend
  alb.ingress.kubernetes.io/healthcheck-path: /api/health

  # Protocol to use when talking to the backend pods
  alb.ingress.kubernetes.io/backend-protocol: HTTP
```

---

## Cross-Namespace Routing

ALB ingress can only route to services in the SAME namespace. For multi-namespace services, create an ingress PER namespace but with the SAME group:

```yaml
# order-ingress (in order-service namespace)
metadata:
  namespace: order-service
  annotations:
    alb.ingress.kubernetes.io/group.name: "vosukula-shared-alb"

# payment-ingress (in payment-service namespace)
metadata:
  namespace: payment-service
  annotations:
    alb.ingress.kubernetes.io/group.name: "vosukula-shared-alb"
```

Same ALB. Different namespaces. Each ingress routes to its own namespace's services.

---

## Commands

```bash
# Check all ingresses and their ALB
kubectl get ingress -A

# See which group each belongs to
kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} group={.metadata.annotations.alb\.ingress\.kubernetes\.io/group\.name}{"\n"}{end}'

# Check ALB in AWS
aws elbv2 describe-load-balancers --query "LoadBalancers[*].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}"
```

---

## When to Use Separate ALBs

| Situation | Use |
|---|---|
| Dev/staging/prod all on same cluster | Separate ALB per environment |
| Internal vs external services | Separate (different `scheme: internal` vs `internet-facing`) |
| Different SSL certs per domain | Separate (though one ALB can have multiple certs) |
| Cost optimization | SHARED — one ALB for everything |
| All services on same domain/subdomain pattern | SHARED |

---

## Cost Breakdown

| Component | Cost |
|---|---|
| ALB fixed cost | ~$16/month per ALB |
| LCU (data processing) | ~$0.008 per LCU-hour |
| Data transfer | Standard AWS data transfer rates |

**One ALB handling 5 ingresses = $16/month**
**Five separate ALBs = $80/month**

The LCU cost is the same either way (same traffic volume). Only the fixed cost multiplies.

---

## Migration Steps (Multiple → Shared)

```bash
# 1. Add group.name to ALL ingress files (same value)
#    alb.ingress.kubernetes.io/group.name: "vosukula-shared-alb"

# 2. Apply all ingresses
kubectl apply -f kubernetes/ingress/
kubectl apply -f kubernetes/argocd/argocd-ingress.yaml

# 3. Wait for ALB to provision (2-3 min)
kubectl get ingress -A
# All should show the SAME ALB address

# 4. Update Route53 — all CNAMEs point to the one shared ALB
# argocd, grafana, sonar, app → same ALB DNS

# 5. Delete old unused ALBs (they'll auto-delete when no ingress references them)
```

---

## Interview Answer

> "We consolidated multiple ALBs into one shared ALB using the `group.name` annotation from the AWS Load Balancer Controller. All our ingresses — ArgoCD, Grafana, SonarQube, and the 3 microservices — share one ALB that routes by host header and path. This saved us $48/month per cluster. The ALB handles HTTPS termination with a single wildcard ACM certificate covering all `*.vosukula.online` subdomains. For cross-namespace routing, each service has its own ingress resource in its namespace, but they all reference the same ALB group."
