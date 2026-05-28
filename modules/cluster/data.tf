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
  pull_through_chart = "${var.cake_agents_chart_repository_prefix}/charts/cake-agents"
  chart_registry     = var.enable_ecr_pull_through ? "oci://${local.registry_host}/${var.cake_agents_chart_repository_prefix}/charts" : var.registry
  kms_admin_principals = compact([
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
    var.deploy_role_name == null ? "" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.deploy_role_name}",
  ])
}
