variable "name" {
  type        = string
  description = "Cluster name. Used for the EKS cluster, VPC (when created), and the karpenter.sh/discovery tag value."
}

variable "hostname" {
  type        = string
  description = "Apex hostname for the cake-agents Ingress (e.g. agents.example.com). Must be covered by certificate_arn and resolvable via route53_zone_id."
}

variable "cake_console_url" {
  type        = string
  description = "Cake Console base URL passed to the cake-agents control plane as the CAKE_CONSOLE_URL environment variable."
  default     = "https://console.cake.ai"
}

variable "certificate_arn" {
  type        = string
  description = "ARN of a validated ACM certificate covering hostname. Typically from the dns module or a pre-existing certificate."
}

variable "route53_zone_id" {
  type        = string
  description = "ID of the Route53 hosted zone for hostname. When set, an alias A record at the apex is created pointing to the cake-agents ALB."
  default     = null
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for a new VPC dedicated to this cluster. Mutually exclusive with vpc_id."
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "ID of an existing VPC to deploy into. Subnets must be supplied via private_subnet_ids and public_subnet_ids. Mutually exclusive with vpc_cidr."
  default     = null

  validation {
    condition     = (var.vpc_cidr == null) != (var.vpc_id == null)
    error_message = "Set exactly one of vpc_cidr (create a new VPC) or vpc_id (bring your own VPC)."
  }
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs when bringing your own VPC. Must span at least 2 AZs. Subnets are auto-tagged for Karpenter and internal-elb discovery."
  default     = []

  validation {
    condition     = var.vpc_id == null || length(var.private_subnet_ids) >= 2
    error_message = "Provide at least 2 private_subnet_ids spanning different AZs when using vpc_id."
  }
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs when bringing your own VPC. Auto-tagged for external-elb discovery."
  default     = []

  validation {
    condition     = var.vpc_id == null || length(var.public_subnet_ids) >= 2
    error_message = "Provide at least 2 public_subnet_ids spanning different AZs when using vpc_id."
  }
}

variable "nat_gateway_per_az" {
  type        = bool
  description = "When creating a VPC: one NAT gateway per AZ (true) or a single shared NAT (false, cheaper). Ignored when bringing your own VPC."
  default     = false
}

variable "kubernetes_version" {
  type        = string
  description = "EKS Kubernetes minor version."
  default     = "1.35"
}

variable "deploy_role_name" {
  type        = string
  description = "IAM role granted admin actions on the per-cluster KMS keys so it can re-apply this module. Set to the role used by your CI/CD; leave null when applying with admin credentials (the account root already has access)."
  default     = null
}

variable "enable_ecr_pull_through" {
  type        = bool
  description = "Provision the ECR pull-through cache rule for the cake-agents chart and warm it before installing Helm. Recommended; disable only if you mirror the chart yourself via registry."
  default     = true
}

variable "registry" {
  type        = string
  description = "OCI registry hosting the cake-agents chart (e.g. oci://my-mirror.example.com/charts). Only required when enable_ecr_pull_through is false."
  default     = null

  validation {
    condition     = var.enable_ecr_pull_through || var.registry != null
    error_message = "registry must be set when enable_ecr_pull_through is false."
  }
}

variable "cake_agents_chart_version" {
  type        = string
  description = "Version of the cake-agents Helm chart to deploy."
}

variable "cake_agents_chart_upstream_registry" {
  type        = string
  description = "Upstream ECR registry hosting the cake-agents chart. Used as the pull-through cache upstream."
  default     = "684117700585.dkr.ecr.us-east-2.amazonaws.com"
}

variable "cake_agents_image_tag" {
  type        = string
  description = "Override for the cake-agents container image tag. When null, the image tag defaults to cake_agents_chart_version."
  default     = null
}

variable "cake_agents_chart_repository_prefix" {
  type        = string
  description = "ECR pull-through cache repository prefix. The chart resolves to <account>.dkr.ecr.<region>.amazonaws.com/<prefix>/charts/cake-agents."
  default     = "cake"
}

variable "database_multi_az" {
  type        = bool
  description = "Provision the RDS instance in multi-AZ mode. Required for production-grade availability."
  default     = false
}

variable "database_deletion_protection" {
  type        = bool
  description = "Set deletion_protection on the RDS instance. Stops terraform destroy and console deletes."
  default     = false
}

variable "database_final_snapshot" {
  type        = bool
  description = "Take a final snapshot when the RDS instance is destroyed."
  default     = false
}

variable "enable_s3_object_storage" {
  type        = bool
  description = "Provision S3 object storage for cake-agents and configure the Helm chart to use it."
  default     = true
}

variable "s3_bucket_name_prefix" {
  type        = string
  description = "Prefix for the generated S3 bucket name used by cake-agents object storage. When null, a prefix is generated from name and truncated as needed. With account-regional bucket namespace, the maximum length is 22 minus the AWS region name length."
  default     = null
}

variable "s3_prefix" {
  type        = string
  description = "Prefix inside the S3 bucket used by cake-agents."
  default     = "sessions"
}

variable "s3_force_destroy" {
  type        = bool
  description = "Whether to force-destroy the cake-agents S3 bucket even when it contains objects."
  default     = false
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

variable "slack" {
  type = object({
    signing_secret = string
    bot_token      = string
  })
  description = "Optional Slack secret configuration for the cake-agents Helm chart. When null, no Slack secret is passed."
  default     = null
  sensitive   = true
}
