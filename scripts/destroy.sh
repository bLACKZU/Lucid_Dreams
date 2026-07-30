#!/usr/bin/env bash
#
# Tears everything down in the right order.
#
# The ALBs are created by the load balancer controller, not by Terraform, so
# Terraform has no idea they exist. Destroying first leaves their network
# interfaces attached to the subnets and the VPC deletion fails with a
# DependencyViolation. Removing the Ingresses makes the controller delete the
# ALBs, leaving a clean VPC for Terraform.
#
# Usage:  ./scripts/destroy.sh                 (Terraform will prompt)
#         ./scripts/destroy.sh -auto-approve   (no prompt)

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
CLUSTER_PREFIX="${CLUSTER_PREFIX:-hello-world}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
INFRA_DIR="${SCRIPT_DIR}/../infra"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="hello-world-tfstate-${ACCOUNT_ID}"

# ---------------------------------------------------------------- kubernetes

CLUSTER=$(aws eks list-clusters --region "$REGION" \
  --query "clusters[?starts_with(@, '$CLUSTER_PREFIX')] | [0]" \
  --output text 2>/dev/null || echo "")

if [ -n "$CLUSTER" ] && [ "$CLUSTER" != "None" ]; then
  echo "Cluster: $CLUSTER"
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null

  # release:namespace
  for entry in monitoring:monitoring hello-world:hello-world; do
    name="${entry%%:*}"
    ns="${entry##*:}"
    if helm status "$name" -n "$ns" >/dev/null 2>&1; then
      echo "Uninstalling $name..."
      helm uninstall "$name" -n "$ns" --wait || true
    fi
  done

  echo "Waiting for the controller to delete the load balancers..."
  remaining=""
  for _ in $(seq 60); do
    remaining=$(aws elbv2 describe-load-balancers --region "$REGION" \
      --query "length(LoadBalancers[?starts_with(LoadBalancerName, 'k8s-')])" \
      --output text 2>/dev/null || echo "0")
    if [ "$remaining" = "0" ]; then break; fi
    sleep 10
  done

  if [ "$remaining" = "0" ]; then
    echo "All load balancers removed."
  else
    echo "WARNING: $remaining load balancer(s) still present."
    echo "Terraform may fail on the VPC. Delete them in the EC2 console and re-run."
  fi
else
  echo "No cluster found with prefix '$CLUSTER_PREFIX' - skipping Kubernetes cleanup."
fi

VPC=$(aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=tag:Project,Values=hello-world-devops-assignment" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")

if [ -n "$VPC" ] && [ "$VPC" != "None" ]; then
  for _ in 1 2 3; do
    sgs=$(aws ec2 describe-security-groups --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC" \
      --query "SecurityGroups[?starts_with(GroupName, 'k8s-')].GroupId" \
      --output text 2>/dev/null || echo "")

    if [ -z "$sgs" ]; then break; fi

    echo "Cleaning up controller-created security groups: $sgs"
    for sg in $sgs; do
      aws ec2 delete-security-group --group-id "$sg" --region "$REGION" >/dev/null 2>&1 || true
    done
    sleep 5
  done
fi

# ---------------------------------------------------------------- terraform

echo
echo "Running terraform destroy..."
cd "$INFRA_DIR"
terraform destroy "$@"

# ------------------------------------------------------------- state bucket
# Last, because Terraform reads and writes this bucket throughout the destroy.

echo
echo "Deleting the Terraform state bucket: $BUCKET"

if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  # Versioning is on, so every object version and delete marker has to go
  # before the bucket itself can be removed.
  aws s3api list-object-versions --bucket "$BUCKET" --output text \
    --query 'Versions[].[Key,VersionId]' 2>/dev/null | while read -r key vid; do
    if [ -n "$key" ]; then
      aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$vid" >/dev/null
    fi
  done

  aws s3api list-object-versions --bucket "$BUCKET" --output text \
    --query 'DeleteMarkers[].[Key,VersionId]' 2>/dev/null | while read -r key vid; do
    if [ -n "$key" ]; then
      aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$vid" >/dev/null
    fi
  done

  aws s3api delete-bucket --bucket "$BUCKET" --region "$REGION"
  echo "Bucket deleted."

  rm -f "${INFRA_DIR}/backend.hcl"
  rm -rf "${INFRA_DIR}/.terraform"
  echo "Removed local backend.hcl and .terraform/"
else
  echo "Bucket not found - nothing to delete."
fi

echo
echo "Teardown complete. Run ./scripts/bootstrap.sh to start again."
