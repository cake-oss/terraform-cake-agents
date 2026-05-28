variable "name" {
  type        = string
  description = "Cluster name. Used for the EKS cluster, VPC (when created), KMS aliases, and the karpenter.sh/discovery tag value."
}

variable "hostname" {
  type        = string
  description = "Apex hostname the cake-agents UI/API is served from (e.g. agents.example.com)."
}

variable "cake_agents_chart_version" {
  type        = string
  description = "Version of the cake-agents Helm chart to deploy."
}

# --- DNS: bring-your-own or let the module create it ---

variable "zone_id" {
  type        = string
  description = "Existing Route53 hosted zone ID for hostname. If null, a new zone is created (and you must delegate it from the parent zone — see the delegation_records output)."
  default     = null
}

variable "certificate_arn" {
  type        = string
  description = "Existing validated ACM certificate ARN covering hostname. Required when zone_id is set; created automatically when zone_id is null."
  default     = null

  validation {
    condition     = (var.zone_id == null && var.certificate_arn == null) || (var.zone_id != null && var.certificate_arn != null)
    error_message = "Provide both zone_id and certificate_arn for bring-your-own DNS, or neither to let the module create both."
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

variable "oidc" {
  type = object({
    provider_id   = string
    domain        = string
    issuer        = string
    client_id     = string
    public_client = bool
    client_secret = optional(string)
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
