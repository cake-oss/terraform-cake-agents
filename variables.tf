variable "name" {
  type        = string
  description = "Cluster name. Used for the EKS cluster, VPC (when created), KMS aliases, and the karpenter.sh/discovery tag value."
}

variable "hostname" {
  type        = string
  description = "Apex hostname the cake-agents UI/API is served from (e.g. agents.example.com). Optional when install_key is set, in which case hostname is discovered from Cake Console."
  default     = null

  validation {
    condition     = var.install_key != null || var.hostname != null
    error_message = "Set hostname when install_key is null. When install_key is set, hostname is looked up automatically."
  }
}

variable "install_key" {
  type        = string
  description = "Install key for Cake-hosted DNS automation. Required when zone_id/certificate_arn are unset."
  default     = null
  sensitive   = true
}

variable "cake_console_url" {
  type        = string
  description = "Cake Console base URL used for install validation-record provisioning."
  default     = "https://console.cake.ai"
}

variable "password_auth_enabled" {
  type        = bool
  description = "Set to true to enable email/password authentication in addition to OIDC. This allows users to log in with an email and password (managed by Cake) instead of an OIDC token."
  default     = true
}

variable "cake_agents_chart_version" {
  type        = string
  description = "Version of the cake-agents Helm chart to deploy."
  default     = "0.12.0"
}

variable "cake_agents_chart_upstream_registry" {
  type        = string
  description = "Upstream ECR registry hosting the cake-agents Helm chart. Used to authenticate Helm when pulling the chart directly."
  default     = "684117700585.dkr.ecr.us-east-2.amazonaws.com"
}

variable "cake_agents_image_tag" {
  type        = string
  description = "Override for the cake-agents container image tag. When null, the image tag defaults to cake_agents_chart_version."
  default     = null
}

# --- DNS: bring-your-own or let the module create it ---

variable "zone_id" {
  type        = string
  description = "Existing Route53 hosted zone ID for hostname. If null, a new zone is created (and you must delegate it from the parent zone — see the nameservers output)."
  default     = null
}

variable "certificate_arn" {
  type        = string
  description = "Existing validated ACM certificate ARN covering hostname. Required with zone_id for bring-your-own DNS; otherwise created and validated automatically via Cake-hosted DNS."
  default     = null

  validation {
    condition = (
      var.zone_id != null &&
      var.certificate_arn != null &&
      var.install_key == null
      ) || (
      var.zone_id == null &&
      var.certificate_arn == null &&
      var.install_key != null
    )
    error_message = "Provide either: (1) zone_id + certificate_arn and omit install_key (bring-your-own DNS), or (2) install_key and omit zone_id/certificate_arn (Cake-hosted DNS)."
  }
}

# --- VPC: bring-your-own or let the module create it ---

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for a new VPC. Mutually exclusive with vpc_id."
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID. When set, also provide private_subnet_ids and public_subnet_ids. Mutually exclusive with vpc_cidr."
  default     = null
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for bring-your-own VPC. Auto-tagged for Karpenter discovery."
  default     = []
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for bring-your-own VPC. Auto-tagged for ALB discovery."
  default     = []
}

variable "nat_gateway_per_az" {
  type        = bool
  description = "When creating a VPC, provision one NAT gateway per AZ. Ignored when bringing your own VPC."
  default     = false
}

# --- Cluster knobs ---

variable "kubernetes_version" {
  type        = string
  description = "EKS Kubernetes minor version."
  default     = "1.35"
}

variable "deploy_role_name" {
  type        = string
  description = "IAM role granted KMS admin on the per-cluster keys. Leave null when applying with admin credentials."
  default     = null
}

variable "enable_ecr_pull_through" {
  type        = bool
  description = "Set up an ECR pull-through cache for the cake-agents chart. Recommended."
  default     = true
}

variable "registry" {
  type        = string
  description = "OCI registry to pull the chart from. Only required when enable_ecr_pull_through is false."
  default     = null
}

variable "database_multi_az" {
  type        = bool
  description = "Provision RDS in multi-AZ mode."
  default     = false
}

variable "database_deletion_protection" {
  type        = bool
  description = "Set deletion_protection on the RDS instance."
  default     = false
}

variable "database_final_snapshot" {
  type        = bool
  description = "Take a final snapshot on RDS destroy."
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

variable "enable_karpenter_drain" {
  type        = bool
  description = "On destroy, block the Karpenter Helm uninstall until Karpenter has drained and terminated the nodes it launched (the NodePool is deleted first). Prevents orphaned worker nodes whose ENIs block subnet/VPC teardown. Requires the aws CLI on the machine running terraform. Set false to skip the wait and rely on enable_eni_cleanup."
  default     = true
}

variable "enable_eni_cleanup" {
  type        = bool
  description = "On destroy, run an aws-cli local-exec that deletes leftover detached ENIs left in the VPC, which EKS/VPC-CNI can leak and which block subnet/VPC deletion. Node termination is handled by enable_karpenter_drain (Karpenter nodes) and Terraform (system node group); this only sweeps ENIs. Requires the aws CLI on the machine running terraform. Set false to skip."
  default     = true
}

variable "extra_hosts" {
  type        = list(string)
  description = "Additional entries appended to the cake-agents controlPlane.extraHosts. The OIDC issuer host is added automatically."
  default     = []
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
  description = "Optional OIDC configuration for the cake-agents Helm chart."
  default     = null
  sensitive   = true
}

variable "slack" {
  type = object({
    signing_secret = string
    bot_token      = string
  })
  description = "Optional Slack credentials for the cake-agents Helm chart."
  default     = null
  sensitive   = true
}
