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

  cake_agents_chart_version = var.cake_agents_chart_version
}

output "delegation_records" {
  description = "Add the ns records to your parent zone to complete DNS delegation."
  value       = module.cake_agents.delegation_records
}

output "cluster_name" {
  value = module.cake_agents.cluster_name
}
