#!/bin/bash
set -euo pipefail
source ./scripts/config.sh

echo "========================================="
echo "Installing Argo Rollouts"
echo "========================================="

./kubectl.exe create namespace argo-rollouts \
  --dry-run=client -o yaml | ./kubectl.exe apply -f -

./kubectl.exe apply -n argo-rollouts \
  --server-side \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

echo "Waiting for Argo Rollouts controller..."
./kubectl.exe wait --for=condition=available deployment \
  --all -n argo-rollouts --timeout=120s

./kubectl.exe get pods -n argo-rollouts

echo "========================================="
echo "Argo Rollouts installed!"
echo ""
echo "To use canary/blue-green deployments:"
echo "  Set rollout.enabled=true in charts/microservice/values-<service>.yaml"
echo ""
echo "Optional: Install kubectl plugin for rollout management:"
echo "  curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64"
echo "  chmod +x kubectl-argo-rollouts-linux-amd64"
echo "  sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts"
echo "========================================="
