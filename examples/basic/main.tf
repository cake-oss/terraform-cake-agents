terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "cake_agents" {
  source = "../../"

  name     = var.name
  hostname = var.hostname
  vpc_cidr = "10.0.0.0/16"

  oidc = {
    # The OIDC provider ID is an arbitrary string used to identify the provider
    # in Cake Agents. In the future, we will support multiple SSO providers,
    # and this ID will be used to distinguish between them. For now, it can just
    # be "oidc".
    provider_id = "oidc"
    # Set `domain` to require users log in with an email address from a specific
    # domain (e.g. your company SSO).
    domain = "example.com"
    # The OIDC issuer URL. This is the URL that Cake Agents will use to fetch
    # the provider's public keys and verify tokens. It must be a valid OIDC
    # issuer that conforms to the OIDC discovery spec (i.e. it must have a
    # well-known configuration endpoint at `${issuer}/.well-known/openid-configuration`).
    issuer = "https://oidc.example.com"
    # The client ID that Cake Agents will expect in the OIDC token. This should
    # match the client ID configured in your OIDC provider for the Cake Agents
    # application.
    client_id = "cake-agents"
    # The client secret associated with the above client ID.
    # This is only needed if `public_client` is false.
    client_secret = var.oidc_client_secret
    # Set `public_client` to true if your OIDC provider does not require a
    # client secret and leave `client_secret` blank in that case.
    public_client = false
  }

  cake_agents_chart_version = var.cake_agents_chart_version
}

output "delegation_records" {
  description = "Add the ns records to your parent zone to complete DNS delegation."
  value       = module.cake_agents.delegation_records
}

output "cluster_name" {
  value = module.cake_agents.cluster_name
}
