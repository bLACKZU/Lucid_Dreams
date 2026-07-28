terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.47.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.1"
    }

    tls = {                             #this is for OIDC issuer's root CA thumbprint
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }

    cloudinit = {                       #this is for bootstrap script required for nodes and for joining to the control plane
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.4"
    }
  }

  # use_lockfile (native S3 state locking, no DynamoDB table) needs >= 1.10
  required_version = ">= 1.10.0, < 2.0.0"

  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
