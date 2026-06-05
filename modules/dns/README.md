# modules/dns

Route53 hosted zone + validated wildcard ACM certificate for a cake-agents cluster.

Outputs the `nameservers` list — add those NS records to your parent zone so the child zone resolves. Certificate validation hangs on first apply until that delegation lands.

If you already manage DNS elsewhere, skip this module entirely and pass `zone_id` + `certificate_arn` directly to the root module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_acm_certificate.wildcard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.wildcard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route53_record.validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Apex hostname for the cluster's hosted zone (e.g. agents.example.com). A wildcard ACM cert is issued for this name and *.<name>. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_acm_validation_records"></a> [acm\_validation\_records](#output\_acm\_validation\_records) | ACM validation CNAMEs (informational — they're already created in this zone). |
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | Validated ACM certificate ARN. Pass to the cluster module as certificate\_arn. |
| <a name="output_nameservers"></a> [nameservers](#output\_nameservers) | NS records to add to the parent zone for delegation. Depends only on the hosted zone, so it resolves from a zone-only targeted apply. |
| <a name="output_nameservers_bind"></a> [nameservers\_bind](#output\_nameservers\_bind) | NS records in BIND zone-file format, ready to paste into the parent zone. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | Route53 hosted zone ID. Pass to the cluster module as route53\_zone\_id. |
| <a name="output_zone_name"></a> [zone\_name](#output\_zone\_name) | Route53 hosted zone name. |
<!-- END_TF_DOCS -->
