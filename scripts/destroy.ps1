$ErrorActionPreference = "Stop"

$Region = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }
$ClusterPrefix = if ($env:CLUSTER_PREFIX) { $env:CLUSTER_PREFIX } else { "hello-world" }

$InfraDir = Join-Path $PSScriptRoot "..\infra"

$AccountId = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0 -or -not $AccountId) {
    throw "Could not determine the AWS account. Is the AWS CLI configured?"
}
$Bucket = "hello-world-tfstate-$AccountId"


$Cluster = aws eks list-clusters --region $Region `
    --query "clusters[?starts_with(@, '$ClusterPrefix')] | [0]" --output text

if ($Cluster -and $Cluster -ne "None") {
    Write-Host "Cluster: $Cluster"
    aws eks update-kubeconfig --name $Cluster --region $Region | Out-Null

    foreach ($entry in @(@("monitoring", "monitoring"), @("hello-world", "hello-world"))) {
        $name = $entry[0]
        $ns = $entry[1]
        helm status $name -n $ns 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Uninstalling $name..."
            helm uninstall $name -n $ns --wait
        }
    }

    Write-Host "Waiting for the controller to delete the load balancers..."
    $remaining = "unknown"
    foreach ($i in 1..60) {
        $remaining = aws elbv2 describe-load-balancers --region $Region `
            --query "length(LoadBalancers[?starts_with(LoadBalancerName, 'k8s-')])" --output text
        if ($remaining -eq "0") { break }
        Start-Sleep -Seconds 10
    }

    if ($remaining -eq "0") {
        Write-Host "All load balancers removed."
    } else {
        Write-Warning "$remaining load balancer(s) still present."
        Write-Warning "Terraform may fail on the VPC. Delete them in the EC2 console and re-run."
    }
} else {
    Write-Host "No cluster found with prefix '$ClusterPrefix' - skipping Kubernetes cleanup."
}


$Vpc = aws ec2 describe-vpcs --region $Region `
    --filters "Name=tag:Project,Values=hello-world-devops-assignment" `
    --query "Vpcs[0].VpcId" --output text

if ($Vpc -and $Vpc -ne "None") {
    foreach ($attempt in 1..3) {
        $sgs = aws ec2 describe-security-groups --region $Region `
            --filters "Name=vpc-id,Values=$Vpc" `
            --query "SecurityGroups[?starts_with(GroupName, 'k8s-')].GroupId" --output text

        if (-not $sgs -or $sgs.Trim() -eq "") { break }

        Write-Host "Cleaning up controller-created security groups: $sgs"
        foreach ($sg in ($sgs -split "\s+")) {
            if ($sg) {
                aws ec2 delete-security-group --group-id $sg --region $Region 2>&1 | Out-Null
            }
        }
        Start-Sleep -Seconds 5
    }
}


Write-Host ""
Write-Host "Running terraform destroy..."
Push-Location $InfraDir
try {
    terraform destroy @args
    if ($LASTEXITCODE -ne 0) { throw "terraform destroy failed" }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Deleting the Terraform state bucket: $Bucket"

$buckets = aws s3api list-buckets --query "Buckets[].Name" --output text
if (($buckets -split "\s+") -contains $Bucket) {

    # Versioning is on, so every object version and delete marker has to go
    # before the bucket itself can be removed.
    foreach ($query in @("Versions[].[Key,VersionId]", "DeleteMarkers[].[Key,VersionId]")) {
        $rows = aws s3api list-object-versions --bucket $Bucket --output text --query $query
        if ($rows) {
            foreach ($line in ($rows -split "`n")) {
                $parts = $line.Trim() -split "\s+"
                if ($parts.Count -ge 2 -and $parts[0]) {
                    aws s3api delete-object --bucket $Bucket --key $parts[0] --version-id $parts[1] | Out-Null
                }
            }
        }
    }

    aws s3api delete-bucket --bucket $Bucket --region $Region
    if ($LASTEXITCODE -ne 0) { throw "Failed to delete bucket $Bucket" }
    Write-Host "Bucket deleted."

    Remove-Item (Join-Path $InfraDir "backend.hcl") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $InfraDir ".terraform") -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed local backend.hcl and .terraform/"
} else {
    Write-Host "Bucket not found - nothing to delete."
}

Write-Host ""
Write-Host "Teardown complete. Run .\scripts\bootstrap.ps1 to start again."
