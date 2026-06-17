data "aws_iam_policy_document" "cake_agents_s3_pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_s3_bucket" "cake_agents" {
  count = var.enable_s3_object_storage ? 1 : 0

  bucket_prefix    = local.s3_bucket_name_prefix
  bucket_namespace = "account-regional"
  force_destroy    = var.s3_force_destroy
}

resource "aws_iam_role" "cake_agents_s3" {
  count = var.enable_s3_object_storage ? 1 : 0

  name               = "${var.name}-cake-agents-s3"
  assume_role_policy = data.aws_iam_policy_document.cake_agents_s3_pod_identity_assume.json
}

data "aws_iam_policy_document" "cake_agents_s3" {
  count = var.enable_s3_object_storage ? 1 : 0

  statement {
    sid = "ListBucket"
    actions = [
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [aws_s3_bucket.cake_agents[0].arn]
  }

  statement {
    sid = "ReadWriteObjects"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetObject",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.cake_agents[0].arn}/*"]
  }
}

resource "aws_iam_role_policy" "cake_agents_s3" {
  count = var.enable_s3_object_storage ? 1 : 0

  name   = "s3-object-storage"
  role   = aws_iam_role.cake_agents_s3[0].id
  policy = data.aws_iam_policy_document.cake_agents_s3[0].json
}

resource "aws_eks_pod_identity_association" "cake_agents_s3" {
  count = var.enable_s3_object_storage ? 1 : 0

  cluster_name    = module.eks.cluster_name
  namespace       = kubernetes_namespace_v1.cake_agents.metadata[0].name
  service_account = "cake-agents"
  role_arn        = aws_iam_role.cake_agents_s3[0].arn
}
