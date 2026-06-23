output "cluster_name" {
  description = "EKS cluster name."
  value       = module.cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint."
  value       = module.cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the EKS cluster."
  value       = module.cluster.cluster_certificate_authority_data
}

output "vpc_id" {
  description = "ID of the VPC the cluster runs in."
  value       = module.cluster.vpc_id
}

output "hostname" {
  description = "Apex hostname for cake-agents."
  value       = local.hostname
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket provisioned for cake-agents object storage. Null when S3 object storage is disabled."
  value       = module.cluster.s3_bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket provisioned for cake-agents object storage. Null when S3 object storage is disabled."
  value       = module.cluster.s3_bucket_arn
}

output "nameservers" {
  description = "Deprecated: nameserver delegation output from the legacy module-managed DNS flow. Always null in the install_key and bring-your-own DNS flows."
  value       = null
}

output "nameservers_bind" {
  description = "Deprecated: nameserver delegation output from the legacy module-managed DNS flow. Always null in the install_key and bring-your-own DNS flows."
  value       = null
}

output "acm_validation_records" {
  description = "ACM validation CNAMEs for the install_key flow (informational). Null when bringing your own DNS with certificate_arn."
  value = var.install_key == null ? null : nonsensitive([
    for dvo in aws_acm_certificate.cake_hosted[0].domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ])
}
