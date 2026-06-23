#!/bin/bash
set -euo pipefail

source ./scripts/config.sh

echo "========================================="
echo "Installing AWS Load Balancer Controller"
echo "========================================="

./helm.exe repo add eks https://aws.github.io/eks-charts
./helm.exe repo update

# FIX: Added line-continuation backslashes and mapped your IAM role
./helm.exe upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::$AWS_ACCOUNT_ID:role/expense-dev-alb-controller-role

echo "Waiting for controller..."
./kubectl.exe rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s

# FIX: Fixed line-break syntax for the pod lookup
./kubectl.exe get pods \
  -n kube-system \
  -l app.kubernetes.io/name=aws-load-balancer-controller

echo " ###### AWS Load Balancer Controller and ALB Ingress Support done ###### "
