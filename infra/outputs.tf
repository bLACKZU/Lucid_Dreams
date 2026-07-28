output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "lb_controller_irsa_role_arn" {
  description = "IAM role ARN to annotate the aws-load-balancer-controller service account with"
  value       = module.lb_controller_irsa.iam_role_arn
}

/*
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume via OIDC -- set this as the AWS_GITHUB_ACTIONS_ROLE_ARN repo variable"
  value       = module.github_actions_role.arn
}
*/