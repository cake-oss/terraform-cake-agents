module "dns" {
  count  = var.zone_id == null ? 1 : 0
  source = "./modules/dns"

  name = var.hostname
}

locals {
  zone_id         = var.zone_id == null ? module.dns[0].zone_id : var.zone_id
  certificate_arn = var.certificate_arn == null ? module.dns[0].certificate_arn : var.certificate_arn
}

module "cluster" {
  source = "./modules/cluster"

  name     = var.name
  hostname = var.hostname

  route53_zone_id = local.zone_id
  certificate_arn = local.certificate_arn

  vpc_cidr           = var.vpc_cidr
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids  = var.public_subnet_ids
  nat_gateway_per_az = var.nat_gateway_per_az

  kubernetes_version      = var.kubernetes_version
  deploy_role_name        = var.deploy_role_name
  enable_ecr_pull_through = var.enable_ecr_pull_through
  registry                = var.registry

  cake_agents_chart_version = var.cake_agents_chart_version

  database_multi_az            = var.database_multi_az
  database_deletion_protection = var.database_deletion_protection
  database_final_snapshot      = var.database_final_snapshot

  extra_hosts = var.extra_hosts

  oidc  = var.oidc
  slack = var.slack
}
