terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    restful = {
      source  = "magodo/restful"
      version = ">= 0.25.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "cake_agents" {
  source = "../../"

  name        = var.name
  install_key = var.install_key
  vpc_cidr    = var.vpc_cidr

  extra_hosts = var.extra_hosts

  password_auth_enabled = var.password_auth_enabled

  oidc = var.oidc

  cake_console_url = var.cake_console_url

  cake_agents_chart_version           = var.cake_agents_chart_version
  cake_agents_image_tag               = var.cake_agents_image_tag
  cake_agents_chart_upstream_registry = var.cake_agents_chart_upstream_registry
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
  sensitive   = true
}

output "cluster_name" {
  value = module.cake_agents.cluster_name
}

output "cake_agents_url" {
  value = "https://${module.cake_agents.hostname}"
}
