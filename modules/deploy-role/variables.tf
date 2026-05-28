variable "name" {
  type        = string
  description = "Base name for IAM resources. The required policy is created as `<name>-required`; optional policies are `<name>-vpc` and `<name>-dns`. The role (when create_role = true) is named `<name>`."
  default     = "cake-agents-deploy"
}

variable "create_role" {
  type        = bool
  description = "When true, create an IAM role with the trust relationship from assume_role_principals/conditions and attach the required policy (plus any optional policies in attach_optional_policies). When false, only the three policies are created and you attach the ones you need to a role you manage."
  default     = false
}

variable "attach_optional_policies" {
  type        = list(string)
  description = "Which of the optional split policies to attach to the role (the required policy is always attached). Drop \"vpc\" for BYO VPC. Drop \"dns\" for BYO Route53 zone + ACM certificate. All three policies are still created — this only controls attachment."
  default     = ["vpc", "dns"]

  validation {
    condition     = alltrue([for p in var.attach_optional_policies : contains(["vpc", "dns"], p)])
    error_message = "attach_optional_policies entries must be one of: vpc, dns."
  }
}

variable "assume_role_statements" {
  type = list(object({
    principals = list(object({
      type        = string
      identifiers = list(string)
    }))
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  description = "Trust relationship statements for the deploy role. Each entry becomes one statement in the role's assume_role_policy with its principals OR'd and its conditions AND'd. Multiple entries are OR'd at the policy level — use one entry per distinct trust pattern (e.g. one for GitHub Actions, one for SSO admin). Required when create_role is true."
  default     = []
}
