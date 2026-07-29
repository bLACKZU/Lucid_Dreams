#!/usr/bin/env bash

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" = "None" ]; then
  echo "Could not determine the AWS account. Is the AWS CLI configured?" >&2
  exit 1
fi

# Bucket names are globally unique, so the account ID keeps this collision-free.
BUCKET="hello-world-tfstate-${ACCOUNT_ID}"

echo "Account : $ACCOUNT_ID"
echo "Region  : $REGION"
echo "Bucket  : $BUCKET"
echo

if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "Bucket already exists -- skipping creation."
else
  echo "Creating bucket..."

  # us-east-1 is the one region that rejects an explicit LocationConstraint.
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=$REGION" >/dev/null
  fi

  # Recover from a corrupted or accidentally deleted state file.
  aws s3api put-bucket-versioning --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled

  # State can contain resource IDs and sensitive values.
  aws s3api put-bucket-encryption --bucket "$BUCKET" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

  # Make it impossible to expose the bucket publicly later.
  aws s3api put-public-access-block --bucket "$BUCKET" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

  echo "Bucket created (versioned, encrypted, public access blocked)."
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BACKEND_FILE="${SCRIPT_DIR}/../infra/backend.hcl"

cat > "$BACKEND_FILE" <<EOF
bucket = "${BUCKET}"
key    = "hello-world/terraform.tfstate"
region = "${REGION}"
EOF

echo "Wrote infra/backend.hcl"
echo
echo "Next:"
echo "  cd infra"
echo "  terraform init -backend-config=backend.hcl"
echo "  terraform apply"
