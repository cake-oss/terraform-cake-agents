variable "name" {
  type        = string
  description = "Prefix for the IAM policy/role names (e.g. \"prod\")."
}

variable "region" {
  type        = string
  description = "AWS region for IAM-region-agnostic resources to apply in."
  default     = "us-east-2"
}

variable "github_org" {
  type        = string
  description = "GitHub organization that owns the deploying repository."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name that runs the deploy workflow."
}
