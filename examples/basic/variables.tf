variable "name" {
  type        = string
  description = "Cluster name (e.g. \"prod\")."
}

variable "hostname" {
  type        = string
  description = "Apex hostname (e.g. \"agents.example.com\")."
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

variable "extra_hosts" {
  type        = list(string)
  description = "Additional entries appended to the cake-agents controlPlane.extraHosts. The OIDC issuer host is added automatically."
  default     = []
}

variable "oidc_provider_id" {
  type        = string
  description = "OIDC provider ID used to identify the provider in Cake Agents (e.g. \"google\")."
}

variable "oidc_domain" {
  type        = string
  description = "Restrict logins to email addresses from this domain (e.g. your company SSO domain)."
}

variable "oidc_issuer" {
  type        = string
  description = "OIDC issuer URL. Must expose a well-known OpenID configuration endpoint."
}

variable "oidc_client_id" {
  type        = string
  description = "OIDC client ID Cake Agents expects in the token."
}

variable "oidc_client_secret" {
  type        = string
  description = "Client secret for the OIDC provider. Required if `oidc` is set in the module config."
  sensitive   = true
}

variable "oidc_public_client" {
  type        = bool
  description = "Set to true if your OIDC provider does not require a client secret (leave oidc_client_secret blank in that case)."
  default     = false
}
