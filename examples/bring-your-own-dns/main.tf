module "dns" {
  source = "../../modules/dns"

  name = var.hostname
}

module "cake_agents" {
  source = "../../"

  name            = var.name
  hostname        = var.hostname
  zone_id         = module.dns.zone_id
  certificate_arn = module.dns.certificate_arn
  vpc_cidr        = var.vpc_cidr
}
