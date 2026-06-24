#!/bin/bash
set -euo pipefail
source ./scripts/config.sh

echo "========================================="
echo "Phase 1: Installing SonarQube"
echo "========================================="

# Step 1: Create namespace
./kubectl.exe create namespace sonarqube \
  --dry-run=client -o yaml | ./kubectl.exe apply -f -

# Step 2: Add Helm repo
./helm.exe repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
./helm.exe repo update

# Step 3: Install SonarQube
./helm.exe upgrade --install sonarqube \
  sonarqube/sonarqube \
  -n sonarqube \
  -f kubernetes/sonarqube/sonarqube-values.yaml \
  --wait --timeout 10m

# Step 4: Wait for readiness
echo "Waiting for SonarQube to be ready..."
./kubectl.exe rollout status statefulset/sonarqube-sonarqube -n sonarqube --timeout=300s || \
  ./kubectl.exe rollout status deployment/sonarqube-sonarqube -n sonarqube --timeout=300s || true

# Step 5: Apply ingress
./kubectl.exe apply -f kubernetes/ingress/sonarqube-ingress.yaml

# Step 6: Verify
./kubectl.exe get pods -n sonarqube
./kubectl.exe get ingress -n sonarqube

echo "========================================="
echo "Phase 1: SonarQube Setup Complete!"
echo "Access at: https://sonar.vosukula.online"
echo "Default: admin / admin (change on first login)"
echo "========================================="
