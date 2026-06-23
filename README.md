# terraform-cake-agents

Terraform module for installing [Cake Agents](https://cake.ai) on AWS.

A single `terraform apply` provisions a dedicated EKS cluster, supporting infrastructure (VPC, RDS, KMS, ECR pull-through cache, Karpenter, AWS Load Balancer Controller, EBS CSI), and the cake-agents Helm release behind an internet-facing ALB on a hostname you own.

## Quickstart

See **[examples/basic](examples/basic/)** for the full walkthrough (new VPC, Cake-hosted DNS automation) — clone the repo, fill in `terraform.tfvars` including your `install_key`, warm the ECR pull-through cache, then apply.

## Prerequisites

- AWS credentials with the permissions in [modules/deploy-role](modules/deploy-role/) (or admin/SSO credentials)
- `helm` and `aws` CLIs on the machine running `terraform apply` (the module warms the ECR pull-through cache via `helm pull` before installing the chart)
- A Cake install key for DNS automation (`install_key`)

## What gets deployed

| Component | Purpose |
| --- | --- |
| VPC + subnets across 3 AZs | Network for the cluster (or bring your own — see below) |
| EKS cluster | Kubernetes control plane, etcd secrets envelope-encrypted with a per-cluster KMS CMK |
| Karpenter | Workload-node autoscaler (`m5`/`m6i`/`m7i` on-demand) |
| AWS Load Balancer Controller | Provisions the ALB from the cake-agents Ingress |
| EBS CSI driver | Persistent volumes for cake-agents workloads, encrypted with a per-cluster CMK |
| RDS Postgres | State store for cake-agents |
| S3 bucket | Object storage for cake-agents session artifacts |
| ECR pull-through cache | Mirrors the cake-agents chart and images into the caller's ECR |
| cake-agents Helm release | The app, behind `https://<hostname>` |

## Bring your own VPC

Set `vpc_id` plus `private_subnet_ids` and `public_subnet_ids` instead of `vpc_cidr`. Existing subnets are auto-tagged for Karpenter and ALB discovery; the deploying principal needs `ec2:CreateTags` on the supplied subnet IDs.

## DNS modes

By default, set `install_key` and let the module create + validate ACM DNS records through Cake-hosted DNS automation.

For bring-your-own DNS, set both `zone_id` and `certificate_arn`, and omit `install_key`.

## CI/CD with GitHub Actions

See [examples/github-actions](examples/github-actions/). The example provisions the GitHub OIDC provider and a deploy role that trusts your `<org>/<repo>` and attaches the bundled IAM policies from [modules/deploy-role](modules/deploy-role/). Other CI systems can attach the policy ARNs (returned as a map by `module.deploy.policy_arns`) to any role.

## Modules

| Path                                        | Description                                                                         |
| ------------------------------------------- | ----------------------------------------------------------------------------------- |
| [modules/cluster](modules/cluster/)         | The cluster itself: VPC, EKS, Karpenter, RDS, LBC, EBS CSI, ECR cache, Helm release |
| [modules/dns](modules/dns/)                 | Legacy Route53 zone + wildcard ACM cert flow                                        |
| [modules/deploy-role](modules/deploy-role/) | IAM policies split by component (and optional role) for CI/CD                       |

## Examples

| Path                                                | Description                                                |
| --------------------------------------------------- | ---------------------------------------------------------- |
| [examples/basic](examples/basic/)                   | One `terraform apply`, new VPC, Cake-hosted DNS automation |
| [examples/github-actions](examples/github-actions/) | OIDC provider + deploy role for GitHub Actions             |

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
| <a name="requirement_restful"></a> [restful](#requirement\_restful) | >= 0.25.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_restful"></a> [restful](#provider\_restful) | >= 0.25.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | ./modules/cluster | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_acm_certificate.cake_hosted](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.cake_hosted](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [restful_operation.cake_hosted_acm_validation_records](https://registry.terraform.io/providers/magodo/restful/latest/docs/resources/operation) | resource |
| [restful_operation.cake_hosted_hostname](https://registry.terraform.io/providers/magodo/restful/latest/docs/resources/operation) | resource |
| [restful_operation.cake_hosted_managed_dns](https://registry.terraform.io/providers/magodo/restful/latest/docs/resources/operation) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cake_agents_chart_upstream_registry"></a> [cake\_agents\_chart\_upstream\_registry](#input\_cake\_agents\_chart\_upstream\_registry) | Upstream ECR registry hosting the cake-agents Helm chart. Used to authenticate Helm when pulling the chart directly. | `string` | `"684117700585.dkr.ecr.us-east-2.amazonaws.com"` | no |
| <a name="input_cake_agents_chart_version"></a> [cake\_agents\_chart\_version](#input\_cake\_agents\_chart\_version) | Version of the cake-agents Helm chart to deploy. | `string` | n/a | yes |
| <a name="input_cake_console_url"></a> [cake\_console\_url](#input\_cake\_console\_url) | Cake Console base URL used for install validation-record provisioning. | `string` | `"https://console.cake.ai"` | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | Existing validated ACM certificate ARN covering hostname. Required with zone\_id for bring-your-own DNS; otherwise created and validated automatically via Cake-hosted DNS. | `string` | `null` | no |
| <a name="input_database_deletion_protection"></a> [database\_deletion\_protection](#input\_database\_deletion\_protection) | Set deletion\_protection on the RDS instance. | `bool` | `false` | no |
| <a name="input_database_final_snapshot"></a> [database\_final\_snapshot](#input\_database\_final\_snapshot) | Take a final snapshot on RDS destroy. | `bool` | `false` | no |
| <a name="input_database_multi_az"></a> [database\_multi\_az](#input\_database\_multi\_az) | Provision RDS in multi-AZ mode. | `bool` | `false` | no |
| <a name="input_deploy_role_name"></a> [deploy\_role\_name](#input\_deploy\_role\_name) | IAM role granted KMS admin on the per-cluster keys. Leave null when applying with admin credentials. | `string` | `null` | no |
| <a name="input_enable_ecr_pull_through"></a> [enable\_ecr\_pull\_through](#input\_enable\_ecr\_pull\_through) | Set up an ECR pull-through cache for the cake-agents chart. Recommended. | `bool` | `true` | no |
| <a name="input_enable_s3_object_storage"></a> [enable\_s3\_object\_storage](#input\_enable\_s3\_object\_storage) | Provision S3 object storage for cake-agents and configure the Helm chart to use it. | `bool` | `true` | no |
| <a name="input_extra_hosts"></a> [extra\_hosts](#input\_extra\_hosts) | Additional entries appended to the cake-agents controlPlane.extraHosts. The OIDC issuer host is added automatically. | `list(string)` | `[]` | no |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Apex hostname the cake-agents UI/API is served from (e.g. agents.example.com). Optional when install\_key is set, in which case hostname is discovered from Cake Console. | `string` | `null` | no |
| <a name="input_install_key"></a> [install\_key](#input\_install\_key) | Install key for Cake-hosted DNS automation. Required when zone\_id/certificate\_arn are unset. | `string` | `null` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | EKS Kubernetes minor version. | `string` | `"1.35"` | no |
| <a name="input_name"></a> [name](#input\_name) | Cluster name. Used for the EKS cluster, VPC (when created), KMS aliases, and the karpenter.sh/discovery tag value. | `string` | n/a | yes |
| <a name="input_nat_gateway_per_az"></a> [nat\_gateway\_per\_az](#input\_nat\_gateway\_per\_az) | When creating a VPC, provision one NAT gateway per AZ. Ignored when bringing your own VPC. | `bool` | `false` | no |
| <a name="input_oidc"></a> [oidc](#input\_oidc) | Optional OIDC configuration for the cake-agents Helm chart. | <pre>object({<br/>    provider_id   = string<br/>    domain        = string<br/>    issuer        = string<br/>    client_id     = string<br/>    public_client = bool<br/>    client_secret = optional(string)<br/>    scopes        = optional(list(string))<br/>  })</pre> | `null` | no |
| <a name="input_password_auth_enabled"></a> [password\_auth\_enabled](#input\_password\_auth\_enabled) | Set to true to enable email/password authentication in addition to OIDC. This allows users to log in with an email and password (managed by Cake) instead of an OIDC token. | `bool` | `true` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs for bring-your-own VPC. Auto-tagged for Karpenter discovery. | `list(string)` | `[]` | no |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | Public subnet IDs for bring-your-own VPC. Auto-tagged for ALB discovery. | `list(string)` | `[]` | no |
| <a name="input_registry"></a> [registry](#input\_registry) | OCI registry to pull the chart from. Only required when enable\_ecr\_pull\_through is false. | `string` | `null` | no |
| <a name="input_s3_bucket_name_prefix"></a> [s3\_bucket\_name\_prefix](#input\_s3\_bucket\_name\_prefix) | Prefix for the generated S3 bucket name used by cake-agents object storage. When null, a prefix is generated from name and truncated as needed. With account-regional bucket namespace, the maximum length is 22 minus the AWS region name length. | `string` | `null` | no |
| <a name="input_s3_force_destroy"></a> [s3\_force\_destroy](#input\_s3\_force\_destroy) | Whether to force-destroy the cake-agents S3 bucket even when it contains objects. | `bool` | `false` | no |
| <a name="input_s3_prefix"></a> [s3\_prefix](#input\_s3\_prefix) | Prefix inside the S3 bucket used by cake-agents. | `string` | `"sessions"` | no |
| <a name="input_slack"></a> [slack](#input\_slack) | Optional Slack credentials for the cake-agents Helm chart. | <pre>object({<br/>    signing_secret = string<br/>    bot_token      = string<br/>  })</pre> | `null` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for a new VPC. Mutually exclusive with vpc\_id. | `string` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing VPC ID. When set, also provide private\_subnet\_ids and public\_subnet\_ids. Mutually exclusive with vpc\_cidr. | `string` | `null` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Existing Route53 hosted zone ID for hostname. If null, a new zone is created (and you must delegate it from the parent zone — see the nameservers output). | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_acm_validation_records"></a> [acm\_validation\_records](#output\_acm\_validation\_records) | ACM validation CNAMEs for the install\_key flow (informational). Null when bringing your own DNS with certificate\_arn. |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64-encoded certificate authority data for the EKS cluster. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | EKS cluster API endpoint. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS cluster name. |
| <a name="output_hostname"></a> [hostname](#output\_hostname) | Apex hostname for cake-agents. |
| <a name="output_nameservers"></a> [nameservers](#output\_nameservers) | Deprecated: nameserver delegation output from the legacy module-managed DNS flow. Always null in the install\_key and bring-your-own DNS flows. |
| <a name="output_nameservers_bind"></a> [nameservers\_bind](#output\_nameservers\_bind) | Deprecated: nameserver delegation output from the legacy module-managed DNS flow. Always null in the install\_key and bring-your-own DNS flows. |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | ARN of the S3 bucket provisioned for cake-agents object storage. Null when S3 object storage is disabled. |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | Name of the S3 bucket provisioned for cake-agents object storage. Null when S3 object storage is disabled. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC the cluster runs in. |
<!-- END_TF_DOCS -->
