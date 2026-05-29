# Pull-through cache that resolves the cake-agents chart and images from
# var.cake_agents_chart_upstream_registry into the caller's ECR. Disabling
# this requires providing your own var.registry.

locals {
  upstream_account_id = split(".", vars.cake_agents_chart_upstream_registry)[0]
}

resource "aws_iam_role" "pull_through_cache" {
  count = var.enable_ecr_pull_through ? 1 : 0

  name = "${var.name}-pull-through-cache"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "pullthroughcache.ecr.amazonaws.com" }
        Action    = "sts:AssumeRole"
      },
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${local.upstream_account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "pull_through_cache" {
  count = var.enable_ecr_pull_through ? 1 : 0

  name = "${var.name}-pull-through-cache"
  role = aws_iam_role.pull_through_cache[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetAuthorizationToken",
        "ecr:BatchImportUpstreamImage",
        "ecr:BatchGetImage",
        "ecr:GetImageCopyStatus",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_ecr_pull_through_cache_rule" "cake_agents" {
  count = var.enable_ecr_pull_through ? 1 : 0

  ecr_repository_prefix = var.cake_agents_chart_repository_prefix
  upstream_registry_url = var.cake_agents_chart_upstream_registry
  custom_role_arn       = aws_iam_role.pull_through_cache[0].arn
}

# Default EKS / Karpenter node policies (AmazonEC2ContainerRegistryReadOnly)
# don't include ecr:BatchImportUpstreamImage or ecr:CreateRepository, which
# are required to trigger pull-through cache imports on first pull.
resource "aws_iam_policy" "node_ecr_pull_through" {
  count = var.enable_ecr_pull_through ? 1 : 0

  name        = "${var.name}-node-ecr-pull-through"
  description = "Allow ${var.name} nodes to trigger ECR pull-through cache imports"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "PullThroughImport"
      Effect = "Allow"
      Action = [
        "ecr:BatchImportUpstreamImage",
        "ecr:CreateRepository",
      ]
      Resource = "*"
    }]
  })
}
