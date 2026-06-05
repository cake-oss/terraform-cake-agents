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

output "nameservers" {
  description = "NS records to add to your parent zone for delegation. Null when bringing your own zone. Resolves from a zone-only targeted apply, so you can delegate before the full apply."
  value       = var.zone_id == null ? module.dns[0].nameservers : null
}

output "nameservers_bind" {
  description = "NS records in BIND zone-file format, ready to paste into the parent zone. Null when bringing your own zone."
  value       = var.zone_id == null ? module.dns[0].nameservers_bind : null
}

output "acm_validation_records" {
  description = "ACM validation CNAMEs (informational — already created in the managed zone). Null when bringing your own zone."
  value       = var.zone_id == null ? module.dns[0].acm_validation_records : null
}
