data "aws_ecr_authorization_token" "cake_upstream_ecr" {
  registry_id = split(".", var.cake_agents_chart_upstream_registry)[0]
}

data "aws_region" "current" {}

data "aws_eks_cluster_auth" "cluster" {
  name = module.cake_agents.cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = module.cake_agents.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cake_agents.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }

  registries = [
    {
      url      = "oci://${var.cake_agents_chart_upstream_registry}"
      username = data.aws_ecr_authorization_token.cake_upstream_ecr.user_name
      password = data.aws_ecr_authorization_token.cake_upstream_ecr.password
    },
  ]
}

provider "kubectl" {
  host                   = module.cake_agents.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cake_agents.cluster_certificate_authority_data)
  load_config_file       = false
  lazy_load              = true
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "kubernetes" {
  host                   = module.cake_agents.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cake_agents.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "restful" {
  base_url = trimsuffix(var.cake_console_url, "/")

  header = var.install_key == null ? {} : {
    X-Cake-Install-Key = var.install_key
    Content-Type       = "application/json"
  }
}
