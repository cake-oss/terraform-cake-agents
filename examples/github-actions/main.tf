terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# GitHub Actions OIDC provider. AWS verifies the OIDC token presented by
# the workflow against this provider's thumbprint.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# Deploy role scoped to a specific repository (and optionally branches/envs).
# Adjust the `values` to match your GitHub workflow trigger.
module "deploy" {
  source = "../../modules/deploy-role"

  name        = "${var.name}-deploy"
  create_role = true

  assume_role_statements = [
    {
      principals = [{
        type        = "Federated"
        identifiers = [aws_iam_openid_connect_provider.github.arn]
      }]
      conditions = [
        {
          test     = "StringEquals"
          variable = "token.actions.githubusercontent.com:aud"
          values   = ["sts.amazonaws.com"]
        },
        {
          test     = "StringLike"
          variable = "token.actions.githubusercontent.com:sub"
          values   = ["repo:${var.github_org}/${var.github_repo}:*"]
        },
      ]
    },
  ]
}

output "role_arn" {
  description = "Use as role-to-assume in aws-actions/configure-aws-credentials."
  value       = module.deploy.role_arn
}
