/*
Commented out for now -- out of scope for the current assignment (which asks
only for deploying the app via a pipeline, not provisioning infra via one).
Revisit this once the Terraform CI/CD pipeline work is back in scope.

module "github_oidc_provider" {           #AWS start accepting signed tokens from GitHub
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "5.39.0"

  tags = var.tags
}

data "aws_iam_policy_document" "github_actions_terraform" {
  statement {
    sid    = "InfraManagement"
    effect = "Allow"
    actions = [
      "ec2:*",
      "eks:*",
      "iam:*",
      "kms:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "logs:*",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "TerraformStateBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketVersioning",
    ]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket}",
      "arn:aws:s3:::${var.tf_state_bucket}/*",
    ]
  }
}

resource "aws_iam_policy" "github_actions_terraform" {
  name   = "${var.cluster_name}-github-actions-terraform"
  policy = data.aws_iam_policy_document.github_actions_terraform.json
  tags   = var.tags
}

module "github_actions_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "5.39.0"

  name = "${var.cluster_name}-github-actions"

  subjects = [
    "${var.github_org}/${var.github_repo}:ref:${var.github_oidc_ref}",
  ]

  policies = {
    terraform = aws_iam_policy.github_actions_terraform.arn
  }

  tags = var.tags

  depends_on = [module.github_oidc_provider]
}
*/
