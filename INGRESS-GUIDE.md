# Ingress & ALB Architecture — How Traffic Reaches Your Pods

---

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            INTERNET                                       │
│                               │                                           │
│                 User types: argocd.vosukula.online                         │
│                               │                                           │
│                               ▼                                           │
│                     ┌──────────────────┐                                  │
│                     │    Route53 DNS    │                                  │
│                     │  *.vosukula.online│                                  │
│                     │  → CNAME to ALB  │                                  │
│                     └────────┬─────────┘                                  │
│                               │                                           │
│                               ▼                                           │
│      ┌────────────────────────────────────────────────┐                   │
│      │     APPLICATION LOAD BALANCER (ALB)             │  ← AWS resource  │
│      │     (vosukula-shared-alb)                       │     (Layer 7)    │
│      │                                                │                   │
│      │  Listener: HTTPS:443                           │                   │
│      │  Cert: *.vosukula.online (ACM wildcard)        │                   │
│      │                                                │                   │
│      │  Rules (host + path routing):                  │                   │
│      │  ┌──────────────────────────────────────────┐  │                   │
│      │  │ argocd.vosukula.online  → TG: argocd     │  │                   │
│      │  │ grafana.vosukula.online → TG: grafana    │  │                   │
│      │  │ app.vosukula.online/order → TG: order    │  │                   │
│      │  │ app.vosukula.online/payment → TG: payment│  │                   │
│      │  │ app.vosukula.online/user → TG: user      │  │                   │
│      │  └──────────────────────────────────────────┘  │                   │
│      └───────────────────────┬────────────────────────┘                   │
│                               │ routes to Pod IPs directly                │
│                               │ (target-type: ip)                         │
│                               ▼                                           │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │                    EKS CLUSTER (expense-dev)                        │   │
│  │                                                                    │   │
│  │  ┌──────────────────────────────────────────────────────────────┐  │   │
│  │  │  AWS Load Balancer Controller (pod in kube-system)           │  │   │
│  │  │  ├── Watches all Ingress resources with class: alb           │  │   │
│  │  │  ├── Creates/updates ALB rules in AWS                        │  │   │
│  │  │  ├── Registers pod IPs as targets                            │  │   │
│  │  │  └── Uses IRSA (no access keys) to call AWS APIs             │  │   │
│  │  └──────────────────────────────────────────────────────────────┘  │   │
│  │                                                                    │   │
│  │  ┌──────────────┐  ┌───────────────┐  ┌──────────────┐            │   │
│  │  │ order-service │  │payment-service│  │ user-service │            │   │
│  │  │ (pod :5000)  │  │ (pod :5000)   │  │ (pod :5000)  │            │   │
│  │  └──────────────┘  └───────────────┘  └──────────────┘            │   │
│  │                                                                    │   │
│  │  ┌──────────────┐  ┌──────────────┐                               │   │
│  │  │ argocd-server│  │   grafana    │                                │   │
│  │  │ (pod :443)   │  │ (pod :80)    │                                │   │
│  │  └──────────────┘  └──────────────┘                                │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## How the Pieces Fit Together

| Step | Component | Role |
|---|---|---|
| 1 | **You** | Write an Ingress YAML (host, path, service, annotations) |
| 2 | **AWS LB Controller** | Reads Ingress → calls AWS API → creates ALB + rules + targets |
| 3 | **ALB** | Receives traffic → routes by host/path → sends to pod IP:port |
| 4 | **Route53** | Maps subdomain → ALB DNS name (CNAME record) |
| 5 | **ACM** | Provides wildcard SSL cert to ALB (HTTPS termination) |

---

## What We Use vs What Exists

| Type | Layer | What It Does | We Use? |
|---|---|---|---|
| **Classic Load Balancer (CLB)** | Layer 4 | Old, basic TCP/HTTP routing | ❌ No |
| **Network Load Balancer (NLB)** | Layer 4 | Ultra-fast TCP/UDP, static IP | ❌ No |
| **Application Load Balancer (ALB)** | Layer 7 | HTTP/HTTPS, host/path routing, WebSocket | ✅ Yes |
| **Nginx Ingress Controller** | Layer 7 | Self-managed, runs as pod | ❌ No |
| **AWS Load Balancer Controller** | K8s Controller | Watches Ingress, creates ALBs | ✅ Yes |

---

## Flow: What Happens When You Apply an Ingress

```
1. You apply: kubectl apply -f ingress.yaml
       ↓
2. Kubernetes stores the Ingress resource in etcd
       ↓
3. AWS LB Controller (running as pod) detects new Ingress
       ↓
4. Controller reads annotations:
   - group.name → merge with existing ALB or create new
   - scheme → internet-facing or internal
   - certificate-arn → which SSL cert to use
   - target-type: ip → route directly to pod IPs
       ↓
5. Controller calls AWS APIs:
   - CreateLoadBalancer (if new group)
   - CreateTargetGroup (for the backend service)
   - CreateRule (host + path → target group)
   - RegisterTargets (pod IPs)
       ↓
6. ALB is live in AWS (takes 2-3 minutes first time)
       ↓
7. You add Route53 CNAME: subdomain → ALB DNS name
       ↓
8. Users access https://subdomain.vosukula.online ✅
```

---

## Key Annotations Explained

```yaml
annotations:
  # Which ingress controller handles this
  kubernetes.io/ingress.class: alb

  # Merge multiple Ingresses into ONE ALB (cost saving)
  alb.ingress.kubernetes.io/group.name: "vosukula-shared-alb"

  # Public internet vs internal VPC only
  alb.ingress.kubernetes.io/scheme: internet-facing

  # Route directly to pod IPs (not via NodePort)
  alb.ingress.kubernetes.io/target-type: ip

  # HTTPS + HTTP listeners (redirect HTTP→HTTPS)
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
  alb.ingress.kubernetes.io/ssl-redirect: '443'

  # Wildcard ACM cert for HTTPS
  alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."

  # Protocol to talk to pods (HTTP for most, HTTPS for ArgoCD)
  alb.ingress.kubernetes.io/backend-protocol: HTTP

  # Health check path for the target group
  alb.ingress.kubernetes.io/healthcheck-path: /
```

---

## Target Types: IP vs Instance

| Type | How It Routes | When to Use |
|---|---|---|
| `ip` (our setup) | ALB → Pod IP directly (bypasses NodePort) | EKS with VPC CNI (recommended) |
| `instance` | ALB → Node IP:NodePort → kube-proxy → Pod | Legacy, extra hop |

We use `ip` mode — ALB sends traffic directly to pod IPs. Faster, no extra hops.

---

## Cross-Namespace Routing

ALB Ingress can only target services in its **own namespace**. For multi-namespace routing, each namespace gets its own Ingress resource but they share the same ALB via `group.name`:

```
order-service namespace:    order-ingress    → group: vosukula-shared-alb
payment-service namespace:  payment-ingress  → group: vosukula-shared-alb
user-service namespace:     user-ingress     → group: vosukula-shared-alb
argocd namespace:           argocd-ingress   → group: vosukula-shared-alb
monitoring namespace:       grafana-ingress  → group: vosukula-shared-alb
```

Result: ONE ALB, all namespaces, host-based + path-based routing.

---

## IRSA: How the Controller Accesses AWS

The AWS LB Controller needs to create ALBs — that requires AWS API access.

```
EKS OIDC Provider
    ↓ trusts
ServiceAccount: aws-load-balancer-controller (in kube-system)
    ↓ annotated with
IAM Role: expense-dev-alb-controller-role
    ↓ has permissions to
Create ALBs, Target Groups, Listeners, Rules
```

No access keys stored. Pod gets temporary credentials automatically via IRSA.

---

## Troubleshooting

| Issue | Check | Fix |
|---|---|---|
| Ingress has no ADDRESS | `kubectl describe ingress` → Events | Check cert ARN, ALB controller running |
| 502 Bad Gateway | Target group has no healthy targets | Check pod is Running + readiness probe passing |
| 404 Not Found | Path doesn't match Flask routes | Add matching routes to Flask app |
| CertificateNotFound | Wrong/expired ACM ARN | Update cert ARN in ingress annotations |
| Backend service not found | Service not in same namespace as Ingress | Use per-namespace ingress with group.name |
| ALB not created | Controller not installed | `kubectl get pods -n kube-system \| grep aws-load` |

---

## Cost

| Item | Cost |
|---|---|
| ALB (fixed) | ~$16/month per ALB |
| LCU (traffic) | ~$0.008/LCU-hour |
| Multiple ingresses, same group | $0 extra (shared ALB) |
| Route53 hosted zone | $0.50/month |
| ACM certificate | Free |

**One shared ALB for everything = $16/month total** for all your services.
