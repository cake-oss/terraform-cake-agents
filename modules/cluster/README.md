# modules/cluster

Provisions everything to run cake-agents on AWS:

- VPC (or attaches to your existing one)
- EKS cluster with Karpenter, the AWS Load Balancer Controller, and the EBS CSI driver
- RDS Postgres for cake-agents state
- S3 object storage for cake-agents session artifacts (default-on)
- ECR pull-through cache for the cake-agents Helm chart (default-on)
- The cake-agents Helm release + ALB Ingress + Route53 alias record

## Bring your own VPC

Either set `vpc_cidr` (and the module creates a VPC) or set `vpc_id` + `private_subnet_ids` + `public_subnet_ids`. Existing subnets are auto-tagged with `karpenter.sh/discovery=<var.name>`, `kubernetes.io/role/internal-elb=1`, and `kubernetes.io/role/elb=1` so Karpenter and the AWS Load Balancer Controller can discover them. The caller needs `ec2:CreateTags` on the supplied subnets.

## Pull-through cache and chart warmup

When `enable_ecr_pull_through = true` (default) the module:

1. Creates an ECR pull-through cache rule that resolves `<prefix>/*` from the upstream Cake registry into the caller's ECR.
2. Pulls the cake-agents chart through the cache via `helm pull` before the Helm release runs (the cache populates lazily, and the Helm provider fails fast if the chart isn't cached yet). Retries with exponential backoff.

This requires `helm` and `aws` CLIs on the machine running `terraform apply`. Set `enable_ecr_pull_through = false` and supply your own `registry` if you mirror the chart somewhere else.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.1.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.9 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.1.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.0.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.9 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cake_agents_db"></a> [cake\_agents\_db](#module\_cake\_agents\_db) | terraform-aws-modules/rds/aws | ~> 6.0 |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 21.3.2 |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | 21.3.2 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 6.2.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_db_subnet_group.cake_agents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_ec2_tag.private_subnet_internal_elb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.private_subnet_karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.public_subnet_elb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ecr_pull_through_cache_rule.cake_agents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_pull_through_cache_rule) | resource |
| [aws_eks_pod_identity_association.cake_agents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_eks_pod_identity_association.lbc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_iam_policy.lbc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.node_ecr_pull_through](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.cake_agents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lbc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.pull_through_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cake_agents_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.pull_through_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lbc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.ebs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_alias.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.ebs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_route53_record.cake_agents_apex](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.cake_agents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_security_group.cake_agents_db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [helm_release.aws_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.cake_agents](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.karpenter](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.karpenter_ec2nodeclass](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.karpenter_nodepool](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.storageclass_gp3](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_annotations.gp2_not_default](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/annotations) | resource |
| [kubernetes_ingress_v1.cake_agents](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_v1) | resource |
| [kubernetes_namespace_v1.cake_agents](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.cake_agents_db_creds](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.cake_agents_oidc_creds](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.cake_agents_slack_creds](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [random_password.cake_agents_db](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [time_sleep.eks_auth_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.cake_agents_pod_identity_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cake_agents_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ebs_csi_pod_identity_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lbc_pod_identity_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_roles.sso_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_lb.cake_agents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cake_agents_chart_repository_prefix"></a> [cake\_agents\_chart\_repository\_prefix](#input\_cake\_agents\_chart\_repository\_prefix) | ECR pull-through cache repository prefix. The chart resolves to <account>.dkr.ecr.<region>.amazonaws.com/<prefix>/charts/cake-agents. | `string` | `"cake"` | no |
| <a name="input_cake_agents_chart_upstream_registry"></a> [cake\_agents\_chart\_upstream\_registry](#input\_cake\_agents\_chart\_upstream\_registry) | Upstream ECR registry hosting the cake-agents chart. Used as the pull-through cache upstream. | `string` | `"684117700585.dkr.ecr.us-east-2.amazonaws.com"` | no |
| <a name="input_cake_agents_chart_version"></a> [cake\_agents\_chart\_version](#input\_cake\_agents\_chart\_version) | Version of the cake-agents Helm chart to deploy. | `string` | n/a | yes |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ARN of a validated ACM certificate covering hostname. Typically from the dns module or a pre-existing certificate. | `string` | n/a | yes |
| <a name="input_database_deletion_protection"></a> [database\_deletion\_protection](#input\_database\_deletion\_protection) | Set deletion\_protection on the RDS instance. Stops terraform destroy and console deletes. | `bool` | `false` | no |
| <a name="input_database_final_snapshot"></a> [database\_final\_snapshot](#input\_database\_final\_snapshot) | Take a final snapshot when the RDS instance is destroyed. | `bool` | `false` | no |
| <a name="input_database_multi_az"></a> [database\_multi\_az](#input\_database\_multi\_az) | Provision the RDS instance in multi-AZ mode. Required for production-grade availability. | `bool` | `false` | no |
| <a name="input_deploy_role_name"></a> [deploy\_role\_name](#input\_deploy\_role\_name) | IAM role granted admin actions on the per-cluster KMS keys so it can re-apply this module. Set to the role used by your CI/CD; leave null when applying with admin credentials (the account root already has access). | `string` | `null` | no |
| <a name="input_enable_ecr_pull_through"></a> [enable\_ecr\_pull\_through](#input\_enable\_ecr\_pull\_through) | Provision the ECR pull-through cache rule for the cake-agents chart and warm it before installing Helm. Recommended; disable only if you mirror the chart yourself via registry. | `bool` | `true` | no |
| <a name="input_enable_s3_object_storage"></a> [enable\_s3\_object\_storage](#input\_enable\_s3\_object\_storage) | Provision S3 object storage for cake-agents and configure the Helm chart to use it. | `bool` | `true` | no |
| <a name="input_extra_hosts"></a> [extra\_hosts](#input\_extra\_hosts) | Additional entries appended to the cake-agents controlPlane.extraHosts. The OIDC issuer host is added automatically. | `list(string)` | `[]` | no |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Apex hostname for the cake-agents Ingress (e.g. agents.example.com). Must be covered by certificate\_arn and resolvable via route53\_zone\_id. | `string` | n/a | yes |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | EKS Kubernetes minor version. | `string` | `"1.35"` | no |
| <a name="input_name"></a> [name](#input\_name) | Cluster name. Used for the EKS cluster, VPC (when created), and the karpenter.sh/discovery tag value. | `string` | n/a | yes |
| <a name="input_nat_gateway_per_az"></a> [nat\_gateway\_per\_az](#input\_nat\_gateway\_per\_az) | When creating a VPC: one NAT gateway per AZ (true) or a single shared NAT (false, cheaper). Ignored when bringing your own VPC. | `bool` | `false` | no |
| <a name="input_oidc"></a> [oidc](#input\_oidc) | Optional OIDC configuration for the cake-agents Helm chart. When null, no OIDC block is passed. | <pre>object({<br/>    provider_id   = string<br/>    domain        = string<br/>    issuer        = string<br/>    client_id     = string<br/>    public_client = bool<br/>    client_secret = optional(string)<br/>    scopes        = optional(list(string))<br/>  })</pre> | `null` | no |
| <a name="input_password_auth_enabled"></a> [password\_auth\_enabled](#input\_password\_auth\_enabled) | Set to true to enable email/password authentication in addition to OIDC. This allows users to log in with an email and password (managed by Cake) instead of an OIDC token. | `bool` | `true` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs when bringing your own VPC. Must span at least 2 AZs. Subnets are auto-tagged for Karpenter and internal-elb discovery. | `list(string)` | `[]` | no |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | Public subnet IDs when bringing your own VPC. Auto-tagged for external-elb discovery. | `list(string)` | `[]` | no |
| <a name="input_registry"></a> [registry](#input\_registry) | OCI registry hosting the cake-agents chart (e.g. oci://my-mirror.example.com/charts). Only required when enable\_ecr\_pull\_through is false. | `string` | `null` | no |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | ID of the Route53 hosted zone for hostname. When set, an alias A record at the apex is created pointing to the cake-agents ALB. | `string` | `null` | no |
| <a name="input_s3_bucket_name_prefix"></a> [s3\_bucket\_name\_prefix](#input\_s3\_bucket\_name\_prefix) | Prefix for the generated S3 bucket name used by cake-agents object storage. When null, a prefix is generated from name and truncated as needed. With account-regional bucket namespace, the maximum length is 22 minus the AWS region name length. | `string` | `null` | no |
| <a name="input_s3_force_destroy"></a> [s3\_force\_destroy](#input\_s3\_force\_destroy) | Whether to force-destroy the cake-agents S3 bucket even when it contains objects. | `bool` | `false` | no |
| <a name="input_s3_prefix"></a> [s3\_prefix](#input\_s3\_prefix) | Prefix inside the S3 bucket used by cake-agents. | `string` | `"sessions"` | no |
| <a name="input_slack"></a> [slack](#input\_slack) | Optional Slack secret configuration for the cake-agents Helm chart. When null, no Slack secret is passed. | <pre>object({<br/>    signing_secret = string<br/>    bot_token      = string<br/>  })</pre> | `null` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for a new VPC dedicated to this cluster. Mutually exclusive with vpc\_id. | `string` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of an existing VPC to deploy into. Subnets must be supplied via private\_subnet\_ids and public\_subnet\_ids. Mutually exclusive with vpc\_cidr. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alb_hostname"></a> [alb\_hostname](#output\_alb\_hostname) | ALB hostname for the cluster. Used as the target for DNS records pointing to cake-agents. |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64-encoded cluster CA certificate. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | EKS cluster API endpoint. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS cluster name. |
| <a name="output_node_security_group_id"></a> [node\_security\_group\_id](#output\_node\_security\_group\_id) | Security group attached to EKS-managed and Karpenter nodes. Use as the target for VPC endpoint rules or other ingress. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Private subnet IDs the cluster uses. |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | ARN of the S3 bucket provisioned for cake-agents object storage. Null when S3 object storage is disabled. |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | Name of the S3 bucket provisioned for cake-agents object storage. Null when S3 object storage is disabled. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC the cluster runs in (either the one created by this module or var.vpc\_id). |
<!-- END_TF_DOCS -->
