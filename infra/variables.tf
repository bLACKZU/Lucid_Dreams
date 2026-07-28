variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Base name for the EKS cluster"
  type        = string
  default     = "hello-world"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets and nodes across"
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT Gateway instead of one per AZ"
  type        = bool
  default     = true
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 4
}

variable "node_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 2
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS public API endpoint is enabled. Private access from within the VPC is always enabled regardless of this setting."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint. Defaults open so the cluster is usable out of the box from any machine or CI/CD runner (GitHub-hosted runners have no stable IP to allowlist). Real access is still gated by IAM authentication + Kubernetes RBAC"
  default     = ["0.0.0.0/0"]
}

variable "cluster_enabled_log_types" {
  description = "EKS control plane log types to ship to CloudWatch Logs"
  type        = list(string)
  default     = ["api", "audit"]
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project = "hello-world-devops-assignment"
  }
}

# variable "github_org" {
#   description = "GitHub org/user that owns the repo allowed to assume the CI IAM role via OIDC"
#   type        = string
# }

# variable "github_repo" {
#   description = "GitHub repo name (without org prefix) allowed to assume the CI IAM role via OIDC"
#   type        = string
# }

# variable "github_oidc_ref" {
#   description = "Git ref the CI role's trust policy is restricted to, e.g. refs/heads/main. Keep this narrow -- it's what stops any branch/fork from assuming a role with broad infra permissions."
#   type        = string
#   default     = "refs/heads/main"
# }

# variable "tf_state_bucket" {
#   description = "Name of the S3 bucket used for Terraform remote state (must match backend.hcl) -- used to scope the CI role's S3 permissions to only this bucket instead of all of S3"
#   type        = string
# }
