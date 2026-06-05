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
  vpc_cidr = var.vpc_cidr

  extra_hosts = var.extra_hosts

  oidc = {
    provider_id   = var.oidc_provider_id
    domain        = var.oidc_domain
    issuer        = var.oidc_issuer
    client_id     = var.oidc_client_id
    client_secret = var.oidc_client_secret
    public_client = var.oidc_public_client
  }

  cake_agents_chart_version = var.cake_agents_chart_version
}

output "nameservers" {
  description = "Add these NS records to your parent zone to complete DNS delegation."
  value       = module.cake_agents.nameservers
}

output "nameservers_bind" {
  description = "NS records in BIND zone-file format, ready to paste into the parent zone."
  value       = module.cake_agents.nameservers_bind
}

output "acm_validation_records" {
  description = "ACM validation CNAMEs (informational — already created in the managed zone)."
  value       = module.cake_agents.acm_validation_records
}

output "cluster_name" {
  value = module.cake_agents.cluster_name
}
