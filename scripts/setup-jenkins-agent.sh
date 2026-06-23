#!/bin/bash

set -e

echo "========================================="
echo "Jenkins Agent Setup"
echo "========================================="

REGISTRY_REGION="us-east-1"
EKS_CLUSTER="expense-dev"

echo
echo "========================================="
echo "1. Installing Java 21"
echo "========================================="

sudo dnf install -y java-21-amazon-corretto

java -version

echo
echo "========================================="
echo "2. Installing Git"
echo "========================================="

sudo dnf install -y git

git --version

echo
echo "========================================="
echo "3. Installing kubectl"
echo "========================================="

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

chmod +x kubectl

sudo mv kubectl /usr/local/bin/

kubectl version --client

echo
echo "========================================="
echo "4. Installing Terraform"
echo "========================================="

sudo yum install -y yum-utils

sudo yum-config-manager 
--add-repo 
https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

sudo yum install -y terraform

terraform version

echo
echo "========================================="
echo "5. Installing Docker"
echo "========================================="

sudo dnf config-manager 
--add-repo 
https://download.docker.com/linux/rhel/docker-ce.repo

sudo dnf install -y 
docker-ce 
docker-ce-cli 
containerd.io

sudo systemctl enable docker

sudo systemctl start docker

sudo usermod -aG docker ec2-user

docker --version

echo
echo "========================================="
echo "6. Configure EKS Access"
echo "========================================="

aws eks update-kubeconfig 
--region ${REGISTRY_REGION} 
--name ${EKS_CLUSTER}

kubectl get nodes

echo
echo "========================================="
echo "7. Create Jenkins Directories"
echo "========================================="

mkdir -p ~/jenkins

chmod 755 ~/jenkins

echo
echo "========================================="
echo "8. Validate AWS Access"
echo "========================================="

aws sts get-caller-identity

echo
echo "========================================="
echo "9. Validate ECR"
echo "========================================="

aws ecr describe-repositories

echo
echo "========================================="
echo "10. Validation Summary"
echo "========================================="

echo "JAVA:"
java -version

echo
echo "AWS:"
aws --version

echo
echo "GIT:"
git --version

echo
echo "KUBECTL:"
kubectl version --client

echo
echo "TERRAFORM:"
terraform version

echo
echo "DOCKER:"
docker --version

echo
echo "EKS:"
kubectl get nodes

echo
echo "========================================="
echo "Agent Setup Completed"
echo "========================================="
