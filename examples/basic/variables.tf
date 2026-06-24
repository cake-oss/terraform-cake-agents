variable "name" {
  type        = string
  description = "Cluster name (e.g. \"prod\")."
}

variable "region" {
  type        = string
  description = "AWS region to deploy into."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the new VPC. Change this if you intend to peer this VPC with another one that uses a conflicting range."
  default     = "10.0.0.0/16"
}

variable "cake_agents_chart_version" {
  type        = string
  description = "cake-agents chart version. Get the latest from Cake."
}

variable "cake_agents_image_tag" {
  type        = string
  description = "Override for the cake-agents container image tag. When null, the image tag defaults to cake_agents_chart_version."
  default     = null
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

variable "extra_hosts" {
  type        = list(string)
  description = "Additional entries appended to the cake-agents controlPlane.extraHosts. The OIDC issuer host is added automatically."
  default     = []
}

variable "password_auth_enabled" {
  type        = bool
  description = "Set to true to enable email/password authentication in addition to OIDC. This allows users to log in with an email and password (managed by Cake) instead of an OIDC token."
  default     = true
}

variable "cake_console_url" {
  type        = string
  description = "Cake Console base URL used for install validation-record provisioning."
  default     = "https://console.cake.ai"
}

variable "oidc" {
  type = object({
    provider_id   = string
    domain        = string
    issuer        = string
    client_id     = string
    public_client = bool
    client_secret = optional(string)
    scopes        = optional(list(string))
  })
  description = "Optional OIDC configuration for the cake-agents Helm chart. When null, no OIDC block is passed."
  default     = null
  sensitive   = true
}
