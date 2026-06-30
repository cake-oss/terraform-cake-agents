module "cake_agents" {
  source = "../../"

  name        = var.name
  install_key = var.install_key
  vpc_cidr    = var.vpc_cidr

  password_auth_enabled = var.password_auth_enabled

  cake_agents_chart_upstream_registry = var.cake_agents_chart_upstream_registry
}
