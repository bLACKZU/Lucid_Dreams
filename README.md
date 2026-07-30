# Hello World on EKS

Hello World microservice on Amazon EKS. Terraform for infrastructure, Helm for
the workload, GitHub Actions to build and deploy.

Evidence screenshots of the running app and the Grafana dashboards are in
[`screenshots/`](screenshots/).

## Prerequisites

- AWS credentials configured (`aws configure`)
- Terraform >= 1.10
- A Docker Hub account

## 1. Create the Terraform state bucket

From the repository root:

```bash
./scripts/bootstrap.sh
```

```powershell
.\scripts\bootstrap.ps1
```

Creates the S3 state bucket and writes `infra/backend.hcl`.

## 2. Provision the infrastructure

```bash
cd infra
terraform init -backend-config backend.hcl
terraform apply
```

Takes about 15-20 minutes.

## 3. Add repository secrets

**Settings -> Secrets and variables -> Actions -> Secrets**

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key of the identity that ran `terraform apply` |
| `AWS_SECRET_ACCESS_KEY` | Matching secret key |
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `GRAFANA_ADMIN_PASSWORD` | Optional, defaults to `admin` |

## 4. Run the pipeline

**Actions -> Build and Deploy -> Run workflow**

Builds the image, installs the AWS Load Balancer Controller, deploys the app,
and installs Prometheus and Grafana. The job summary lists the URLs for the
app, Grafana and Prometheus.

## 5. Tear everything down

```bash
./scripts/destroy.sh
```

```powershell
.\scripts\destroy.ps1
```

Uninstalls the Helm releases, waits for the load balancers to be removed, runs
`terraform destroy`, and deletes the state bucket.
