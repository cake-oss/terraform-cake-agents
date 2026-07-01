resource "restful_operation" "cake_hosted_hostname" {
  count = var.install_key == null ? 0 : 1

  method = "GET"
  path   = "/api/install/hostname"
}

locals {
  cake_agents_default_chart_version = "0.12.2"
  cake_agents_chart_version         = var.cake_agents_chart_version == null ? local.cake_agents_default_chart_version : trimspace(var.cake_agents_chart_version) == "" ? local.cake_agents_default_chart_version : var.cake_agents_chart_version
  hostname                          = nonsensitive(var.install_key == null ? var.hostname : restful_operation.cake_hosted_hostname[0].output.hostname)
}

resource "aws_acm_certificate" "cake_hosted" {
  count = var.install_key != null ? 1 : 0

  domain_name               = local.hostname
  subject_alternative_names = []
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  cake_hosted_acm_validation_records = var.install_key == null ? [] : [
    for dvo in aws_acm_certificate.cake_hosted[0].domain_validation_options : {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
    }
  ]
}

resource "restful_operation" "cake_hosted_acm_validation_records" {
  count = var.install_key == null ? 0 : 1

  path = "/api/install/validation-records"

  method = "PUT"

  body = {
    records = local.cake_hosted_acm_validation_records
  }
}

resource "aws_acm_certificate_validation" "cake_hosted" {
  count = var.install_key != null ? 1 : 0

  certificate_arn = aws_acm_certificate.cake_hosted[0].arn

  # ACM checks these FQDNs during validation. Records are created via the
  # Cake DNS API above.
  validation_record_fqdns = [
    for dvo in aws_acm_certificate.cake_hosted[0].domain_validation_options : dvo.resource_record_name
  ]

  depends_on = [restful_operation.cake_hosted_acm_validation_records]
}

resource "restful_operation" "cake_hosted_managed_dns" {
  count = var.install_key == null ? 0 : 1

  method = "PUT"
  path   = "/api/install/managed-dns-records"

  body = {
    target = module.cluster.alb_hostname
  }
}


locals {
  zone_id         = var.zone_id
  certificate_arn = var.certificate_arn == null ? aws_acm_certificate_validation.cake_hosted[0].certificate_arn : var.certificate_arn
}

module "cluster" {
  source = "./modules/cluster"

  name     = var.name
  hostname = local.hostname

  cake_console_url = var.cake_console_url

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

  cake_agents_chart_version           = local.cake_agents_chart_version
  cake_agents_chart_upstream_registry = var.cake_agents_chart_upstream_registry
  cake_agents_image_tag               = var.cake_agents_image_tag

  database_multi_az            = var.database_multi_az
  database_deletion_protection = var.database_deletion_protection
  database_final_snapshot      = var.database_final_snapshot

  enable_s3_object_storage = var.enable_s3_object_storage
  s3_bucket_name_prefix    = var.s3_bucket_name_prefix
  s3_prefix                = var.s3_prefix
  s3_force_destroy         = var.s3_force_destroy

  enable_karpenter_drain = var.enable_karpenter_drain
  enable_eni_cleanup     = var.enable_eni_cleanup

  extra_hosts = var.extra_hosts

  oidc  = var.oidc
  slack = var.slack
}
