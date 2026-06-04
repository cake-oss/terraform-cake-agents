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

variable "cake_agents_chart_version" {
  type        = string
  description = "cake-agents chart version. Get the latest from Cake."
}

variable "oidc_client_secret" {
  type        = string
  description = "Client secret for the OIDC provider. Required if `oidc` is set in the module config."
  sensitive   = true
}
