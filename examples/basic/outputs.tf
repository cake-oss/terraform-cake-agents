output "nameservers" {
  description = "Add these NS records to your parent zone to complete DNS delegation."
  value       = module.cake_agents.nameservers
}

output "nameservers_bind" {
  description = "NS records in BIND zone-file format, ready to paste into the parent zone."
  value       = module.cake_agents.nameservers_bind
}

output "acm_validation_records" {
  description = "ACM validation CNAMEs (informational — already created in the managed zone)."
  value       = module.cake_agents.acm_validation_records
  sensitive   = true
}

output "cluster_name" {
  value = module.cake_agents.cluster_name
}

output "cake_agents_url" {
  value = "https://${module.cake_agents.hostname}"
}
