#!/bin/bash
set -euo pipefail

# Check that the script is being run from the repo root directory
if [ ! -f "./scripts/config.sh" ]; then
  echo "ERROR: This script must be run from the repo root directory." >&2
  echo "       e.g. bash scripts/01-install-tools.sh" >&2
  exit 1
fi

source ./scripts/config.sh

echo "========================================="
echo "🚀 Installing Helm"
echo "========================================="

rm -rf windows-amd64/
rm -f helm-v3.18.2-windows-amd64.zip

curl -fLO https://get.helm.sh/helm-v3.18.2-windows-amd64.zip

unzip -o helm-v3.18.2-windows-amd64.zip

mv windows-amd64/helm.exe .

rm -rf windows-amd64/
rm -f helm-v3.18.2-windows-amd64.zip

echo "Helm Version:"
./helm.exe version --short

echo "========================================="
echo "Downloading kubectl"
echo "========================================="

curl -fLO https://dl.k8s.io/release/v1.31.0/bin/windows/amd64/kubectl.exe

echo "kubectl Version:"
./kubectl.exe version --client --short 2>/dev/null || ./kubectl.exe version --client

echo "========================================="
echo "Updating kubeconfig"
echo "========================================="

aws eks update-kubeconfig  \
--region $REGION \
--name $CLUSTER_NAME

echo "========================================="
echo "Verifying Cluster"
echo "========================================="

./kubectl.exe get nodes

echo " ###### Helm install ----  kubernet config --- Cluster Validation done ###### "