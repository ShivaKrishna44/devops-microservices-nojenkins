#!/bin/bash
set -euo pipefail
source ./scripts/config.sh

# Apply argocd namespace from manifest
./kubectl.exe apply -f kubernetes/namespaces/argocd.yaml

./kubectl.exe apply \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for core components..."
./kubectl.exe wait --for=condition=available deployment --all -n argocd --timeout=180s

# Apply ArgoCD ingress
./kubectl.exe apply -f kubernetes/argocd/argocd-ingress.yaml

./kubectl.exe get pods -n argocd
echo " ✔ GitOps ✔ Continuous Deployment "
