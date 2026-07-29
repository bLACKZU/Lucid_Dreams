# Hello World on EKS

Hello World microservice on Amazon EKS. Terraform for infrastructure, Helm for
the workload, GitHub Actions to build and deploy.

## Prerequisites

- AWS credentials configured (`aws configure`)
- Terraform >= 1.10
- A Docker Hub account

## Step 1 — Create the Terraform state bucket

From the repository root:

```bash
./scripts/bootstrap.sh
```

```powershell
.\scripts\bootstrap.ps1
```

Creates the S3 state bucket and writes `infra/backend.hcl`. Safe to re-run.

For a different region, set `AWS_REGION` first (default is `us-east-1`):

```bash
AWS_REGION=eu-west-1 ./scripts/bootstrap.sh
```

```powershell
$env:AWS_REGION = "eu-west-1"; .\scripts\bootstrap.ps1
```
