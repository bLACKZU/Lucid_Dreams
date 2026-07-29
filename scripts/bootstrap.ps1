# Creates the S3 bucket that holds Terraform state, then writes infra/backend.hcl.


$ErrorActionPreference = "Stop"

$Region = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }

$AccountId = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0 -or -not $AccountId) {
    throw "Could not determine the AWS account. Is the AWS CLI configured?"
}

# Bucket names are globally unique, so the account ID keeps this collision-free.
$Bucket = "hello-world-tfstate-$AccountId"

Write-Host "Account : $AccountId"
Write-Host "Region  : $Region"
Write-Host "Bucket  : $Bucket"
Write-Host ""

# Listing buckets avoids head-bucket, whose stderr on a missing bucket trips up
# native-command error handling in Windows PowerShell 5.1.
$existing = aws s3api list-buckets --query "Buckets[].Name" --output text
$exists = ($existing -split "\s+") -contains $Bucket

if ($exists) {
    Write-Host "Bucket already exists -- skipping creation."
} else {
    Write-Host "Creating bucket..."

    # us-east-1 is the one region that rejects an explicit LocationConstraint.
    if ($Region -eq "us-east-1") {
        aws s3api create-bucket --bucket $Bucket --region $Region | Out-Null
    } else {
        aws s3api create-bucket --bucket $Bucket --region $Region `
            --create-bucket-configuration "LocationConstraint=$Region" | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { throw "Failed to create bucket $Bucket" }

    # Recover from a corrupted or accidentally deleted state file.
    aws s3api put-bucket-versioning --bucket $Bucket `
        --versioning-configuration Status=Enabled
    if ($LASTEXITCODE -ne 0) { throw "Failed to enable versioning" }

    # State can contain resource IDs and sensitive values. The JSON goes via a
    # temp file so PowerShell quoting rules don't mangle it on the way to the CLI.
    $encryptionJson = '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -Path $tempFile -Value $encryptionJson -Encoding ascii
        aws s3api put-bucket-encryption --bucket $Bucket `
            --server-side-encryption-configuration "file://$tempFile"
        if ($LASTEXITCODE -ne 0) { throw "Failed to enable encryption" }
    } finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }

    # Make it impossible to expose the bucket publicly later.
    aws s3api put-public-access-block --bucket $Bucket `
        --public-access-block-configuration `
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    if ($LASTEXITCODE -ne 0) { throw "Failed to set public access block" }

    Write-Host "Bucket created (versioned, encrypted, public access blocked)."
}

$backendFile = Join-Path $PSScriptRoot "..\infra\backend.hcl"

@"
bucket = "$Bucket"
key    = "hello-world/terraform.tfstate"
region = "$Region"
"@ | Set-Content -Path $backendFile -Encoding ascii

Write-Host "Wrote infra/backend.hcl"
Write-Host ""
Write-Host "Next:"
Write-Host "  cd infra"
Write-Host "  terraform init -backend-config=backend.hcl"
Write-Host "  terraform apply"
