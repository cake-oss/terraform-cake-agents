output "cluster_name" {
  value = module.cake_agents.cluster_name
}

output "cake_agents_url" {
  value = "https://${module.cake_agents.hostname}"
}

output "zone_id" {
  description = "Route53 hosted zone ID created for demo.cake.ai."
  value       = module.dns.zone_id
}

output "nameservers" {
  description = "Child-zone nameservers delegated from the parent zone."
  value       = module.dns.nameservers
}

output "nameservers_bind" {
  description = "NS records in BIND zone-file format."
  value       = module.dns.nameservers_bind
}

output "acm_validation_records" {
  description = "ACM validation CNAMEs created in the child zone."
  value       = module.dns.acm_validation_records
}
