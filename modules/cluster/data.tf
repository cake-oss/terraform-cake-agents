data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_roles" "sso_admin" {
  name_regex  = "AWSReservedSSO_AWSAdministratorAccess_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

data "aws_vpc" "this" {
  id = local.vpc_id
}

locals {
  create_vpc         = var.vpc_id == null
  vpc_id             = local.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  private_subnet_ids = local.create_vpc ? module.vpc[0].private_subnets : var.private_subnet_ids
  public_subnet_ids  = local.create_vpc ? module.vpc[0].public_subnets : var.public_subnet_ids
  registry_host      = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com"

  sso_admin_arn = length(data.aws_iam_roles.sso_admin.arns) == 0 ? "" : tolist(data.aws_iam_roles.sso_admin.arns)[0]

  # EKS access entries are keyed by the underlying IAM role, not the session.
  # The caller ARN is a session ARN (arn:aws:sts::<acct>:assumed-role/<role>/<session>),
  # so pull out the role name to compare against the SSO admin role.
  caller_role_name    = can(regex(":assumed-role/", data.aws_caller_identity.current.arn)) ? split("/", data.aws_caller_identity.current.arn)[1] : ""
  sso_admin_role_name = local.sso_admin_arn == "" ? "" : reverse(split("/", local.sso_admin_arn))[0]

  # enable_cluster_creator_admin_permissions already grants the running principal
  # admin via the "cluster_creator" access entry. When that principal IS the SSO
  # admin role, adding an explicit sso_admin entry collides on the same role ARN
  # (409 ResourceInUseException), so skip it in that case.
  caller_is_sso_admin = local.caller_role_name != "" && local.caller_role_name == local.sso_admin_role_name

  s3_bucket_name_prefix_max_length = 20 - length(data.aws_region.current.region)
  s3_bucket_name_prefix            = coalesce(var.s3_bucket_name_prefix, substr("${var.name}-cake-agents-", 0, local.s3_bucket_name_prefix_max_length))

  pull_through_chart = "${var.cake_agents_chart_repository_prefix}/charts/cake-agents"
  # Helm pulls the chart directly from the upstream Cake registry, bypassing the
  # pull-through cache so no warmup is required.
  chart_registry = var.enable_ecr_pull_through ? "oci://${var.cake_agents_chart_upstream_registry}/charts" : var.registry
  # Container images are still pulled through the customer's ECR pull-through
  # cache by EKS nodes at runtime.
  image_registry = var.enable_ecr_pull_through ? "${local.registry_host}/${var.cake_agents_chart_repository_prefix}" : trimsuffix(trimprefix(var.registry, "oci://"), "/charts")
  kms_admin_principals = compact([
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
    var.deploy_role_name == null ? "" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.deploy_role_name}",
  ])
}
