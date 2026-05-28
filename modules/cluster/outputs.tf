output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "vpc_id" {
  description = "ID of the VPC the cluster runs in (either the one created by this module or var.vpc_id)."
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs the cluster uses."
  value       = local.private_subnet_ids
}

output "node_security_group_id" {
  description = "Security group attached to EKS-managed and Karpenter nodes. Use as the target for VPC endpoint rules or other ingress."
  value       = module.eks.node_security_group_id
}
