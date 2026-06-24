# Phases Implementation Guide — DevOps Microservices Platform

Complete step-by-step guide for implementing all 5 advanced phases on top of the existing CI/CD pipeline.

---

## 📚 Documentation Map

| # | Document | Covers | When to Read |
|---|---|---|---|
| 1 | **DEPLOYMENT-GUIDE.md** | Steps 1–9: Full platform setup (Terraform → Jenkins → ArgoCD → Monitoring → SonarQube) | First — gets everything running |
| 2 | **PHASES-IMPLEMENTATION.md** (this file) | Deep-dive into Helm Charts, ArgoCD GitOps flow, Canary/Blue-Green deployments | After base platform is running |
| 3 | **TROUBLESHOOTING.md** | Every error encountered and how it was fixed | Reference when something breaks |

**Prerequisite:** Complete all steps in DEPLOYMENT-GUIDE.md first. This document builds on top of that foundation.

## 🚀 Phase Execution Order

| Phase | What | Install Command | Verify |
|---|---|---|---|
| 4 | Monitoring | `bash scripts/05-install-monitoring.sh` | `kubectl get pods -n monitoring` |
| 2 | Helm Charts | `helm upgrade --install <svc> ./charts/microservice -f charts/microservice/values-<svc>.yaml -n <svc> --create-namespace` | `kubectl get pods -n <svc>` |
| 3 | ArgoCD GitOps | `kubectl apply -f kubernetes/argocd/apps/` | ArgoCD UI → Applications |
| 1 | SonarQube | `bash scripts/06-install-sonarqube.sh` | `https://sonar.vosukula.online` |
| 5 | Argo Rollouts | `bash scripts/07-install-argo-rollouts.sh` | `kubectl get pods -n argo-rollouts` |

## 🛑 Phase Teardown (Reverse Order)

```bash
# Remove Argo Rollouts
./kubectl.exe delete -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
./kubectl.exe delete namespace argo-rollouts

# Remove SonarQube
./helm.exe uninstall sonarqube -n sonarqube
./kubectl.exe delete namespace sonarqube

# Remove ArgoCD Apps (keeps ArgoCD itself running)
./kubectl.exe delete -f kubernetes/argocd/apps/

# Remove Monitoring
./helm.exe uninstall monitoring -n monitoring
./kubectl.exe delete namespace monitoring
```

---

## Current Architecture (Baseline)

```
Developer → Git Push → Jenkins CI → Docker Build → ECR Push → kubectl Deploy → EKS
```

## Target Architecture (After All Phases)

```
Developer → Git Push → Jenkins CI
                         ├── Phase 1: SonarQube Quality Gate
                         ├── Docker Build + ECR Push
                         ├── Phase 2: Helm Chart Package
                         └── Phase 3: Update Git Tag → ArgoCD Auto-Sync → EKS
                                                                      ↓
                                                         Phase 4: Prometheus/Grafana Monitoring
                                                                      ↓
                                                         Phase 5: Argo Rollouts (Canary/Blue-Green)
```

---

## Phase 4 — Prometheus + Grafana + Alertmanager (Monitoring)

**Status:** Already configured, just needs to be deployed.

### What This Does
- Deploys Prometheus (metrics collection) on EKS
- Deploys Grafana (dashboards/visualization) on EKS
- Deploys Alertmanager (alert routing) on EKS
- Provides full cluster and application monitoring

### Prerequisites
- EKS cluster running
- ALB controller installed
- `gp2` StorageClass available

### Step 1 — Create Grafana Secret
```bash
./kubectl.exe create namespace monitoring --dry-run=client -o yaml | ./kubectl.exe apply -f -

./kubectl.exe create secret generic grafana-admin-secret \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=YOUR_PASSWORD \
  -n monitoring
```

### Step 2 — Run Install Script
```bash
bash scripts/05-install-monitoring.sh
```

This script:
- Adds prometheus-community Helm repo
- Creates monitoring namespace
- Installs kube-prometheus-stack (chart v65.1.1) with values from `kubernetes/monitoring/grafana-values.yaml`
- Waits for Grafana deployment readiness

### Step 3 — Apply Grafana Ingress
```bash
./kubectl.exe apply -f kubernetes/ingress/grafana-ingress.yaml
```

### Step 4 — Update Route53
Add CNAME for `grafana.vosukula.online` pointing to the ALB address:
```bash
./kubectl.exe get ingress -n monitoring
# Copy the ADDRESS value → update Route53 CNAME
```

### Step 5 — Add ServiceMonitors for Microservices

Create `kubernetes/monitoring/servicemonitor-apps.yaml`:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: microservices-monitor
  namespace: monitoring
  labels:
    release: monitoring
spec:
  namespaceSelector:
    matchNames:
      - order-service
      - payment-service
      - user-service
  selector:
    matchLabels:
      app: microservice
  endpoints:
    - port: http
      interval: 30s
      path: /metrics
```

Apply:
```bash
./kubectl.exe apply -f kubernetes/monitoring/servicemonitor-apps.yaml
```

### Verification
- Access: `https://grafana.vosukula.online`
- Username: `admin`
- Password: what you set in the secret
- Dashboards: Grafana → Dashboards → Browse → Kubernetes cluster monitoring

---

## Phase 2 — Helm Charts (Packaging Deployments)

**Purpose:** Replace raw `kubectl apply` with versioned, parameterized Helm charts. This gives you rollback, templating, and environment-specific values.

### What This Creates

```
charts/
└── microservice/               ← Generic chart used by all 3 services
    ├── Chart.yaml
    ├── values.yaml             ← Default values
    ├── values-order.yaml       ← Order service overrides
    ├── values-payment.yaml     ← Payment service overrides
    ├── values-user.yaml        ← User service overrides
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        ├── ingress.yaml
        ├── hpa.yaml
        └── _helpers.tpl
```

### Step 1 — Create Chart.yaml
File: `charts/microservice/Chart.yaml`
```yaml
apiVersion: v2
name: microservice
description: Generic Helm chart for Flask microservices
type: application
version: 1.0.0
appVersion: "1.0.0"
```

### Step 2 — Create Default values.yaml
File: `charts/microservice/values.yaml`
```yaml
replicaCount: 2

image:
  repository: 589389425618.dkr.ecr.us-east-1.amazonaws.com/order-service
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 5000

ingress:
  enabled: false
  host: app.vosukula.online
  path: /order
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilization: 70

healthCheck:
  path: /
  port: 5000
```

### Step 3 — Create Per-Service Values

File: `charts/microservice/values-order.yaml`
```yaml
image:
  repository: 589389425618.dkr.ecr.us-east-1.amazonaws.com/order-service
  tag: "1.0"
ingress:
  path: /order
```

File: `charts/microservice/values-payment.yaml`
```yaml
image:
  repository: 589389425618.dkr.ecr.us-east-1.amazonaws.com/payment-service
  tag: "1.0"
ingress:
  path: /payment
```

File: `charts/microservice/values-user.yaml`
```yaml
image:
  repository: 589389425618.dkr.ecr.us-east-1.amazonaws.com/user-service
  tag: "1.0"
ingress:
  path: /user
```

### Step 4 — Create Templates

File: `charts/microservice/templates/deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: {{ .Release.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.port }}
          livenessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: {{ .Values.healthCheck.port }}
            initialDelaySeconds: 10
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: {{ .Values.healthCheck.port }}
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

File: `charts/microservice/templates/service.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
    app: microservice
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
      protocol: TCP
      name: http
  selector:
    app: {{ .Release.Name }}
```

File: `charts/microservice/templates/hpa.yaml`
```yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .Release.Name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Release.Name }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilization }}
{{- end }}
```

---

### Deploy Options — kubectl vs Helm

#### Option A — Deploy with kubectl (current approach)
```bash
kubectl apply -f kubernetes/${SERVICE_NAME}/ -n ${SERVICE_NAME}
kubectl set image deployment/${SERVICE_NAME} ${SERVICE_NAME}=${FULL_IMAGE_NAME} -n ${SERVICE_NAME}
```

#### Option B — Deploy with Helm
```bash
helm upgrade --install ${SERVICE_NAME} ./charts/microservice \
  -f charts/microservice/values-${SERVICE_NAME}.yaml \
  --set image.tag=${IMAGE_TAG} \
  -n ${SERVICE_NAME} --create-namespace
```

#### Option C — Both in Jenkinsfile (with parameter choice)

Updated Jenkinsfile `Deploy to EKS` stage supporting both:
```groovy
stage('Deploy to EKS') {
    steps {
        script {
            echo "🚀 Deploying ${env.SERVICE_NAME} to EKS..."
            
            sh '''
                aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME}
            '''
            
            // OPTION: Choose deployment method via parameter
            if (params.DEPLOY_METHOD == 'helm') {
                sh '''
                    echo "📦 Deploying with Helm..."
                    helm upgrade --install ${SERVICE_NAME} ./charts/microservice \
                      -f charts/microservice/values-${SERVICE_NAME}.yaml \
                      --set image.tag=${IMAGE_TAG} \
                      -n ${SERVICE_NAME} --create-namespace --wait --timeout 5m
                '''
            } else {
                sh '''
                    echo "📋 Deploying with kubectl..."
                    kubectl create namespace ${SERVICE_NAME} --dry-run=client -o yaml | kubectl apply -f -
                    
                    if [ -d "kubernetes/${SERVICE_NAME}" ]; then
                        kubectl apply -f kubernetes/${SERVICE_NAME}/ -n ${SERVICE_NAME}
                    fi
                    
                    if kubectl get deployment ${SERVICE_NAME} -n ${SERVICE_NAME} >/dev/null 2>&1; then
                        kubectl set image deployment/${SERVICE_NAME} \
                          ${SERVICE_NAME}=${FULL_IMAGE_NAME} -n ${SERVICE_NAME}
                        kubectl rollout status deployment/${SERVICE_NAME} \
                          -n ${SERVICE_NAME} --timeout=300s
                    fi
                '''
            }
            
            sh 'kubectl get all -n ${SERVICE_NAME}'
        }
    }
}
```

Add to Jenkinsfile parameters block:
```groovy
choice(
    name: 'DEPLOY_METHOD',
    choices: ['kubectl', 'helm', 'argocd'],
    description: 'Deployment method'
)
```

---

## Phase 3 — ArgoCD GitOps (Continuous Deployment)

**Purpose:** Jenkins only builds and pushes images. ArgoCD watches Git and auto-deploys when the image tag changes in the Helm values file. No kubectl/helm in Jenkins deploy stage.

### How GitOps Flow Works

```
1. Jenkins builds image, pushes to ECR with tag "1.5"
2. Jenkins updates charts/microservice/values-order.yaml → image.tag: "1.5"
3. Jenkins commits and pushes this change to Git
4. ArgoCD detects the Git change
5. ArgoCD auto-syncs: deploys the new version to EKS
```

### Step 1 — Create ArgoCD Application CRDs

File: `kubernetes/argocd/apps/order-service.yaml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: order-service
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ShivaKrishna44/devops-microservices-platform.git
    targetRevision: main
    path: charts/microservice
    helm:
      valueFiles:
        - values-order.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: order-service
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

File: `kubernetes/argocd/apps/payment-service.yaml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: payment-service
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ShivaKrishna44/devops-microservices-platform.git
    targetRevision: main
    path: charts/microservice
    helm:
      valueFiles:
        - values-payment.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: payment-service
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

File: `kubernetes/argocd/apps/user-service.yaml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: user-service
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ShivaKrishna44/devops-microservices-platform.git
    targetRevision: main
    path: charts/microservice
    helm:
      valueFiles:
        - values-user.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: user-service
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Step 2 — Apply ArgoCD Applications
```bash
./kubectl.exe apply -f kubernetes/argocd/apps/
```

### Step 3 — Jenkinsfile GitOps Deploy Stage

When `DEPLOY_METHOD == 'argocd'`, Jenkins doesn't deploy directly. Instead it updates the tag in Git:

```groovy
} else if (params.DEPLOY_METHOD == 'argocd') {
    sh '''
        echo "🔄 Updating image tag in Git for ArgoCD..."
        git config user.email "jenkins@vosukula.online"
        git config user.name "Jenkins CI"
        
        # Update the image tag in the values file
        sed -i "s/tag: .*/tag: \\"${IMAGE_TAG}\\"/" \
          charts/microservice/values-${SERVICE_NAME}.yaml
        
        git add charts/microservice/values-${SERVICE_NAME}.yaml
        git commit -m "chore: update ${SERVICE_NAME} image to ${IMAGE_TAG}"
        git push origin main
        
        echo "✅ ArgoCD will auto-sync the new tag"
    '''
}
```

### Step 4 — Verify in ArgoCD UI
- Access: `https://argocd.vosukula.online`
- You'll see all 3 apps with sync status
- On every Git push, ArgoCD auto-deploys

---

## Phase 1 — SonarQube (Code Quality Gate)

**Purpose:** Analyze code quality, find bugs, vulnerabilities, and code smells before Docker build. Pipeline fails if quality gate fails.

### Option A — SonarCloud (SaaS, no infra needed)
1. Sign up at https://sonarcloud.io with GitHub
2. Create org, import your repo
3. Get token from SonarCloud → My Account → Security → Generate Token

### Option B — Self-hosted SonarQube on EKS

#### Step 1 — Install Script
File: `scripts/06-install-sonarqube.sh`
```bash
#!/bin/bash
set -euo pipefail
source ./scripts/config.sh

./kubectl.exe create namespace sonarqube \
  --dry-run=client -o yaml | ./kubectl.exe apply -f -

./helm.exe repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
./helm.exe repo update

./helm.exe upgrade --install sonarqube \
  sonarqube/sonarqube \
  -n sonarqube \
  -f kubernetes/sonarqube/sonarqube-values.yaml \
  --wait --timeout 10m

./kubectl.exe apply -f kubernetes/ingress/sonarqube-ingress.yaml

echo "SonarQube available at: https://sonar.vosukula.online"
echo "Default credentials: admin / admin (change on first login)"
```

#### Step 2 — SonarQube Values
File: `kubernetes/sonarqube/sonarqube-values.yaml`
```yaml
persistence:
  enabled: true
  storageClass: gp2
  size: 10Gi

resources:
  requests:
    cpu: 400m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi

jdbcOverwrite:
  enable: false  # uses embedded H2 for dev — use PostgreSQL for prod
```

#### Step 3 — SonarQube Ingress
File: `kubernetes/ingress/sonarqube-ingress.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sonarqube-ingress
  namespace: sonarqube
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:589389425618:certificate/483235ba-eb66-4a81-b2ab-6244c3f2a2d6"
    alb.ingress.kubernetes.io/healthcheck-path: /api/system/status
    alb.ingress.kubernetes.io/backend-protocol: HTTP
spec:
  ingressClassName: alb
  rules:
  - host: sonar.vosukula.online
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: sonarqube-sonarqube
            port:
              number: 9000
```

#### Step 4 — Sonar Properties Per Service
File: `app/order-service/sonar-project.properties`
```properties
sonar.projectKey=order-service
sonar.projectName=Order Service
sonar.sources=.
sonar.language=py
sonar.python.version=3.11
sonar.sourceEncoding=UTF-8
```
(Same for payment-service and user-service with different projectKey/Name)

#### Step 5 — Add SonarQube Stage to Jenkinsfile

Add between `Build & Test` and `Docker Build & Push`:
```groovy
stage('SonarQube Analysis') {
    steps {
        script {
            echo "🔍 Running SonarQube analysis..."
            dir("app/${env.SERVICE_NAME}") {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=${SERVICE_NAME} \
                          -Dsonar.projectName=${SERVICE_NAME} \
                          -Dsonar.sources=. \
                          -Dsonar.host.url=${SONAR_HOST_URL} \
                          -Dsonar.login=${SONAR_AUTH_TOKEN}
                    '''
                }
            }
        }
    }
}

stage('Quality Gate') {
    steps {
        timeout(time: 5, unit: 'MINUTES') {
            waitForQualityGate abortPipeline: true
        }
    }
}
```

#### Step 6 — Configure SonarQube in Jenkins
1. Manage Jenkins → System → SonarQube servers
2. Name: `SonarQube`
3. URL: `https://sonar.vosukula.online`
4. Token: Add as Secret Text credential

---

## Phase 5 — Blue-Green / Canary Deployments (Argo Rollouts)

**Purpose:** Instead of replacing all pods at once (rolling update), gradually shift traffic to the new version. If something breaks, auto-rollback.

### Strategies

| Strategy | How It Works |
|---|---|
| **Canary** | 20% traffic → new version. If healthy, 50% → 100%. Auto-rollback on failure |
| **Blue-Green** | Deploy new version alongside old. Switch traffic instantly. Keep old as rollback |

### Step 1 — Install Argo Rollouts

File: `scripts/07-install-argo-rollouts.sh`
```bash
#!/bin/bash
set -euo pipefail
source ./scripts/config.sh

./kubectl.exe create namespace argo-rollouts \
  --dry-run=client -o yaml | ./kubectl.exe apply -f -

./kubectl.exe apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

echo "Waiting for Argo Rollouts controller..."
./kubectl.exe wait --for=condition=available deployment \
  --all -n argo-rollouts --timeout=120s

# Install kubectl plugin for rollouts (optional, for CLI management)
echo "Install kubectl argo rollouts plugin:"
echo "  curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64"
echo "  chmod +x kubectl-argo-rollouts-linux-amd64"
echo "  sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts"

./kubectl.exe get pods -n argo-rollouts
echo " ✔ Argo Rollouts installed"
```

### Step 2 — Replace Deployment with Rollout

File: `charts/microservice/templates/rollout.yaml` (replaces deployment.yaml)
```yaml
{{- if .Values.rollout.enabled }}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: {{ .Release.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.port }}
          livenessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: {{ .Values.healthCheck.port }}
            initialDelaySeconds: 10
          readinessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: {{ .Values.healthCheck.port }}
            initialDelaySeconds: 5
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
  strategy:
    {{- if eq .Values.rollout.strategy "canary" }}
    canary:
      steps:
        - setWeight: 20
        - pause: { duration: 60s }
        - setWeight: 50
        - pause: { duration: 60s }
        - setWeight: 80
        - pause: { duration: 30s }
      canaryService: {{ .Release.Name }}-canary
      stableService: {{ .Release.Name }}
    {{- else }}
    blueGreen:
      activeService: {{ .Release.Name }}
      previewService: {{ .Release.Name }}-preview
      autoPromotionEnabled: true
      autoPromotionSeconds: 120
    {{- end }}
{{- end }}
```

### Step 3 — Add Rollout Values

Add to `charts/microservice/values.yaml`:
```yaml
rollout:
  enabled: false          # Set to true to use Rollout instead of Deployment
  strategy: canary        # Options: canary, blueGreen
```

To enable canary for order-service, add to `values-order.yaml`:
```yaml
rollout:
  enabled: true
  strategy: canary
```

### Step 4 — Create Canary/Preview Services

File: `charts/microservice/templates/canary-service.yaml`
```yaml
{{- if and .Values.rollout.enabled (eq .Values.rollout.strategy "canary") }}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-canary
spec:
  type: ClusterIP
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
  selector:
    app: {{ .Release.Name }}
{{- end }}
```

### Step 5 — Monitor Rollout Progress

```bash
# Check rollout status
kubectl argo rollouts get rollout order-service -n order-service

# Watch live
kubectl argo rollouts get rollout order-service -n order-service --watch

# Manually promote (skip pause)
kubectl argo rollouts promote order-service -n order-service

# Abort and rollback
kubectl argo rollouts abort order-service -n order-service
```

### Step 6 — Conditional Deployment in Jenkinsfile

The deployment template handles this automatically:
- If `rollout.enabled: false` → uses standard Deployment (rolling update)
- If `rollout.enabled: true` → uses Rollout CRD (canary/blue-green)

No Jenkinsfile changes needed — ArgoCD deploys whatever the Helm chart generates.

---

## Complete Updated Jenkinsfile (All Phases Combined)

This shows the final Jenkinsfile with all phases integrated:

```groovy
pipeline {
    agent { label 'AGENT' }

    parameters {
        choice(name: 'SERVICE_NAME', choices: ['order-service', 'payment-service', 'user-service'])
        string(name: 'IMAGE_TAG', defaultValue: '', description: 'Leave empty for BUILD_NUMBER')
        choice(name: 'DEPLOY_METHOD', choices: ['kubectl', 'helm', 'argocd'], description: 'Deployment strategy')
        booleanParam(name: 'SKIP_SONAR', defaultValue: false, description: 'Skip SonarQube analysis')
    }

    environment {
        AWS_ACCOUNT_ID = sh(script: "aws sts get-caller-identity --query Account --output text", returnStdout: true).trim()
        AWS_DEFAULT_REGION = 'us-east-1'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
        EKS_CLUSTER_NAME = 'expense-dev'
        SERVICE_NAME = "${params.SERVICE_NAME ?: 'order-service'}"
        IMAGE_TAG = "${params.IMAGE_TAG ?: BUILD_NUMBER}"
        FULL_IMAGE_NAME = "${ECR_REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG}"
    }

    stages {
        stage('Checkout') { steps { checkout scm } }

        stage('Build & Test') {
            parallel {
                stage('Build') { steps { dir("app/${env.SERVICE_NAME}") { sh 'echo "Build OK"' } } }
                stage('Test')  { steps { dir("app/${env.SERVICE_NAME}") { sh 'echo "Tests OK"' } } }
            }
        }

        // PHASE 1: SonarQube
        stage('SonarQube Analysis') {
            when { expression { !params.SKIP_SONAR } }
            steps {
                dir("app/${env.SERVICE_NAME}") {
                    withSonarQubeEnv('SonarQube') {
                        sh 'sonar-scanner -Dsonar.projectKey=${SERVICE_NAME}'
                    }
                }
            }
        }

        stage('Quality Gate') {
            when { expression { !params.SKIP_SONAR } }
            steps { timeout(time: 5, unit: 'MINUTES') { waitForQualityGate abortPipeline: true } }
        }

        // Docker Build & Push to ECR
        stage('Docker Build & Push') {
            steps {
                dir("app/${env.SERVICE_NAME}") {
                    sh 'aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}'
                    sh 'docker build -t ${SERVICE_NAME}:${IMAGE_TAG} .'
                    sh 'docker tag ${SERVICE_NAME}:${IMAGE_TAG} ${FULL_IMAGE_NAME}'
                    sh 'docker push ${FULL_IMAGE_NAME}'
                    sh 'docker rmi ${SERVICE_NAME}:${IMAGE_TAG} ${FULL_IMAGE_NAME} || true'
                }
            }
        }

        // PHASE 2/3/Current: Deploy
        stage('Deploy') {
            steps {
                script {
                    sh 'aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME}'

                    if (params.DEPLOY_METHOD == 'helm') {
                        // PHASE 2: Helm
                        sh '''
                            helm upgrade --install ${SERVICE_NAME} ./charts/microservice \
                              -f charts/microservice/values-${SERVICE_NAME}.yaml \
                              --set image.tag=${IMAGE_TAG} \
                              -n ${SERVICE_NAME} --create-namespace --wait --timeout 5m
                        '''
                    } else if (params.DEPLOY_METHOD == 'argocd') {
                        // PHASE 3: GitOps
                        sh '''
                            git config user.email "jenkins@vosukula.online"
                            git config user.name "Jenkins CI"
                            sed -i "s/tag: .*/tag: \\"${IMAGE_TAG}\\"/" charts/microservice/values-${SERVICE_NAME}.yaml
                            git add charts/microservice/values-${SERVICE_NAME}.yaml
                            git commit -m "chore: update ${SERVICE_NAME} to ${IMAGE_TAG}"
                            git push origin main
                        '''
                    } else {
                        // Current: kubectl
                        sh '''
                            kubectl create namespace ${SERVICE_NAME} --dry-run=client -o yaml | kubectl apply -f -
                            kubectl set image deployment/${SERVICE_NAME} ${SERVICE_NAME}=${FULL_IMAGE_NAME} -n ${SERVICE_NAME} || \
                              echo "No existing deployment — first deploy will be handled by ArgoCD or helm"
                        '''
                    }
                }
            }
        }
    }

    post {
        success { echo "✅ SUCCESS: ${env.SERVICE_NAME}:${env.IMAGE_TAG} deployed via ${params.DEPLOY_METHOD}" }
        failure { echo "❌ FAILED: ${env.SERVICE_NAME}" }
        always { deleteDir() }
    }
}
```

---

## Summary — Files To Create For All Phases

```
charts/
└── microservice/
    ├── Chart.yaml
    ├── values.yaml
    ├── values-order.yaml
    ├── values-payment.yaml
    ├── values-user.yaml
    └── templates/
        ├── deployment.yaml
        ├── rollout.yaml
        ├── service.yaml
        ├── canary-service.yaml
        ├── hpa.yaml
        └── _helpers.tpl

kubernetes/
├── argocd/apps/
│   ├── order-service.yaml
│   ├── payment-service.yaml
│   └── user-service.yaml
├── sonarqube/
│   └── sonarqube-values.yaml
├── ingress/
│   └── sonarqube-ingress.yaml
└── monitoring/
    └── servicemonitor-apps.yaml

scripts/
├── 06-install-sonarqube.sh
└── 07-install-argo-rollouts.sh

app/*/sonar-project.properties
```

---

## Implementation Order

| # | Phase | Command to Deploy |
|---|---|---|
| 1 | Monitoring | `bash scripts/05-install-monitoring.sh` |
| 2 | Helm Charts | Create `charts/` directory, then `helm install` |
| 3 | ArgoCD Apps | `kubectl apply -f kubernetes/argocd/apps/` |
| 4 | SonarQube | `bash scripts/06-install-sonarqube.sh` |
| 5 | Argo Rollouts | `bash scripts/07-install-argo-rollouts.sh` |
