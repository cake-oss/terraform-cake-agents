output "cluster_name" {
  description = "EKS cluster name."
  value       = module.cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint."
  value       = module.cluster.cluster_endpoint
}

output "vpc_id" {
  description = "ID of the VPC the cluster runs in."
  value       = module.cluster.vpc_id
}

output "hostname" {
  description = "Apex hostname for cake-agents."
  value       = var.hostname
}

output "delegation_records" {
  description = "NS records to add to your parent zone for delegation, plus ACM validation CNAMEs (informational). Null when bringing your own zone."
  value       = var.zone_id == null ? module.dns[0].delegation_records : null
}
