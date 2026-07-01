module "cake_agents" {
  source = "../../"

  name        = var.name
  install_key = var.install_key
  vpc_cidr    = var.vpc_cidr
}
