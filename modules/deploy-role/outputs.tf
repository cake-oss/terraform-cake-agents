output "policy_arns" {
  description = "Map of policy ARNs keyed by purpose: required (always needed), vpc (only when the root module creates the VPC), dns (only when the root module creates the Route53 zone + ACM cert)."
  value       = local.policy_arns
}

output "policy_jsons" {
  description = "Map of policy document JSONs keyed by purpose. Useful for embedding in externally-managed policies."
  value       = local.policy_jsons
}

output "role_arn" {
  description = "ARN of the deploy role. Null when create_role is false."
  value       = var.create_role ? aws_iam_role.deploy[0].arn : null
}

output "role_name" {
  description = "Name of the deploy role. Null when create_role is false."
  value       = var.create_role ? aws_iam_role.deploy[0].name : null
}
