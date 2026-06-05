output "zone_id" {
  description = "Route53 hosted zone ID. Pass to the cluster module as route53_zone_id."
  value       = aws_route53_zone.this.zone_id
}

output "zone_name" {
  description = "Route53 hosted zone name."
  value       = aws_route53_zone.this.name
}

output "certificate_arn" {
  description = "Validated ACM certificate ARN. Pass to the cluster module as certificate_arn."
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
}

output "nameservers" {
  description = "NS records to add to the parent zone for delegation. Depends only on the hosted zone, so it resolves from a zone-only targeted apply."
  value       = aws_route53_zone.this.name_servers
}

output "nameservers_bind" {
  description = "NS records in BIND zone-file format, ready to paste into the parent zone."
  value = join("\n", [
    for ns in aws_route53_zone.this.name_servers :
    "${trimsuffix(aws_route53_zone.this.name, ".")}. 172800 IN NS ${ns}."
  ])
}

output "acm_validation_records" {
  description = "ACM validation CNAMEs (informational — they're already created in this zone)."
  value = [
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ]
}
