variable "name" {
  type        = string
  description = <<-EOT
    Cluster name. Used to name the EKS cluster and tag the supporting AWS
    resources (VPC, subnets, IAM roles, etc.), so pick something that
    identifies this deployment within your AWS account — e.g. "cake-agents"
    or "cake-agents-prod". Lowercase alphanumeric and hyphens.
  EOT
}

variable "region" {
  type        = string
  description = <<-EOT
    AWS region to deploy into (e.g. "us-east-2"). All resources are created in
    this region, so use one close to your users where the required services
    (EKS, ACM) are available. This is independent of your AWS CLI default
    region.
  EOT
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the new VPC. Change this if you intend to peer this VPC with another one that uses a conflicting range."
  default     = "10.0.0.0/16"
}

variable "cake_agents_chart_upstream_registry" {
  type        = string
  description = "Upstream ECR registry hosting the cake-agents Helm chart."
  default     = "684117700585.dkr.ecr.us-east-2.amazonaws.com"
}

variable "install_key" {
  type        = string
  description = "Install key for Cake-hosted DNS automation."
  sensitive   = true
}

variable "password_auth_enabled" {
  type        = bool
  description = "Set to true to enable email/password authentication. This allows users to log in with an email and password (managed by Cake)."
  default     = true
}
