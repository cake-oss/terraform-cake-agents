module "cake_agents" {
  source = "../../"

  name        = var.name
  install_key = var.install_key
  vpc_cidr    = var.vpc_cidr

  password_auth_enabled = var.password_auth_enabled

  cake_console_url = var.cake_console_url

  cake_agents_chart_version           = var.cake_agents_chart_version
  cake_agents_image_tag               = var.cake_agents_image_tag
  cake_agents_chart_upstream_registry = var.cake_agents_chart_upstream_registry
}
