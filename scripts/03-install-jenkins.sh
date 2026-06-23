#!/bin/bash
set -euo pipefail

source ./scripts/config.sh

echo "========================================="
echo "Installing Jenkins"
echo "========================================="

# Create namespace
./kubectl.exe create namespace jenkins \
  --dry-run=client -o yaml | ./kubectl.exe apply -f -

# Add Jenkins Helm repo
./helm.exe repo add jenkins https://charts.jenkins.io
./helm.exe repo update

# Install/Upgrade Jenkins
./helm.exe upgrade --install jenkins \
  jenkins/jenkins \
  -n jenkins \
  --wait --timeout 5m \
  -f kubernetes/jenkins/jenkins-values.yaml

# Wait for Jenkins to be ready
echo "========================================="
echo "Waiting for Jenkins to be ready..."
echo "========================================="
kubectl rollout status deployment/jenkins -n jenkins --timeout=120s

# Apply Jenkins Ingress
echo "========================================="
echo "Creating Jenkins Ingress"
echo "========================================="
./kubectl.exe apply -f kubernetes/ingress/jenkins-ingress.yaml

echo "========================================="
echo "Jenkins Pods"
echo "========================================="
./kubectl.exe get pods -n jenkins

echo "========================================="
echo "Jenkins Service"
echo "========================================="
./kubectl.exe get svc -n jenkins

echo "========================================="
echo "Jenkins Ingress"
echo "========================================="
./kubectl.exe get ingress -n jenkins

echo "========================================="
echo "Waiting for ALB to be created..."
echo "========================================="
./kubectl.exe describe ingress jenkins-ingress -n jenkins

echo "========================================="
echo "Jenkins Setup Complete!"
echo "Access Jenkins at: https://jenkins.vosukula.online"
echo "========================================="
