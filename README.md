# terraform-cake-agents

Terraform module for installing [Cake Agents](https://cake.ai) on AWS.

A single `terraform apply` provisions a dedicated EKS cluster, supporting infrastructure (VPC, RDS, KMS, ECR pull-through cache, Karpenter, AWS Load Balancer Controller, EBS CSI), and the cake-agents Helm release behind an internet-facing ALB on a hostname you own.

## Quickstart

See **[examples/basic](examples/basic/)** for the full walkthrough (new VPC, new Route53 zone) — clone the repo, fill in `terraform.tfvars`, delegate the DNS zone, warm the ECR pull-through cache, then apply.

## Prerequisites

- AWS credentials with the permissions in [modules/deploy-role](modules/deploy-role/) (or admin/SSO credentials)
- `helm` and `aws` CLIs on the machine running `terraform apply` (the module warms the ECR pull-through cache via `helm pull` before installing the chart)
- Control of the parent DNS zone for your chosen hostname, so you can delegate the child zone the module creates

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
| Route53 hosted zone + wildcard ACM cert | DNS + TLS for the cake-agents hostname (skippable if you already manage these) |
| cake-agents Helm release | The app, behind `https://<hostname>` |

## Bring your own VPC

Set `vpc_id` plus `private_subnet_ids` and `public_subnet_ids` instead of `vpc_cidr`. Existing subnets are auto-tagged for Karpenter and ALB discovery; the deploying principal needs `ec2:CreateTags` on the supplied subnet IDs.

## Bring your own DNS

Set both `zone_id` and `certificate_arn` to use an existing Route53 zone and ACM certificate. The module skips creating its own DNS resources and will fail validation if only one is set.

## CI/CD with GitHub Actions

See [examples/github-actions](examples/github-actions/). The example provisions the GitHub OIDC provider and a deploy role that trusts your `<org>/<repo>` and attaches the bundled IAM policies from [modules/deploy-role](modules/deploy-role/). Other CI systems can attach the policy ARNs (returned as a map by `module.deploy.policy_arns`) to any role.

## Modules

| Path | Description |
| --- | --- |
| [modules/cluster](modules/cluster/) | The cluster itself: VPC, EKS, Karpenter, RDS, LBC, EBS CSI, ECR cache, Helm release |
| [modules/dns](modules/dns/) | Route53 zone + wildcard ACM cert |
| [modules/deploy-role](modules/deploy-role/) | IAM policies split by component (and optional role) for CI/CD |

## Examples

| Path | Description |
| --- | --- |
| [examples/basic](examples/basic/) | One `terraform apply`, new VPC, new DNS zone |
| [examples/github-actions](examples/github-actions/) | OIDC provider + deploy role for GitHub Actions |

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

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | ./modules/cluster | n/a |
| <a name="module_dns"></a> [dns](#module\_dns) | ./modules/dns | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecr_authorization_token.ecr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token) | data source |
| [aws_eks_cluster_auth.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cake_agents_chart_version"></a> [cake\_agents\_chart\_version](#input\_cake\_agents\_chart\_version) | Version of the cake-agents Helm chart to deploy. | `string` | n/a | yes |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | Existing validated ACM certificate ARN covering hostname. Required when zone\_id is set; created automatically when zone\_id is null. | `string` | `null` | no |
| <a name="input_database_deletion_protection"></a> [database\_deletion\_protection](#input\_database\_deletion\_protection) | Set deletion\_protection on the RDS instance. | `bool` | `false` | no |
| <a name="input_database_final_snapshot"></a> [database\_final\_snapshot](#input\_database\_final\_snapshot) | Take a final snapshot on RDS destroy. | `bool` | `false` | no |
| <a name="input_database_multi_az"></a> [database\_multi\_az](#input\_database\_multi\_az) | Provision RDS in multi-AZ mode. | `bool` | `false` | no |
| <a name="input_deploy_role_name"></a> [deploy\_role\_name](#input\_deploy\_role\_name) | IAM role granted KMS admin on the per-cluster keys. Leave null when applying with admin credentials. | `string` | `null` | no |
| <a name="input_enable_ecr_pull_through"></a> [enable\_ecr\_pull\_through](#input\_enable\_ecr\_pull\_through) | Set up an ECR pull-through cache for the cake-agents chart. Recommended. | `bool` | `true` | no |
| <a name="input_enable_s3_object_storage"></a> [enable\_s3\_object\_storage](#input\_enable\_s3\_object\_storage) | Provision S3 object storage for cake-agents and configure the Helm chart to use it. | `bool` | `true` | no |
| <a name="input_extra_hosts"></a> [extra\_hosts](#input\_extra\_hosts) | Additional entries appended to the cake-agents controlPlane.extraHosts. The OIDC issuer host is added automatically. | `list(string)` | `[]` | no |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Apex hostname the cake-agents UI/API is served from (e.g. agents.example.com). | `string` | n/a | yes |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | EKS Kubernetes minor version. | `string` | `"1.35"` | no |
| <a name="input_name"></a> [name](#input\_name) | Cluster name. Used for the EKS cluster, VPC (when created), KMS aliases, and the karpenter.sh/discovery tag value. | `string` | n/a | yes |
| <a name="input_nat_gateway_per_az"></a> [nat\_gateway\_per\_az](#input\_nat\_gateway\_per\_az) | When creating a VPC, provision one NAT gateway per AZ. Ignored when bringing your own VPC. | `bool` | `false` | no |
| <a name="input_oidc"></a> [oidc](#input\_oidc) | Optional OIDC configuration for the cake-agents Helm chart. | <pre>object({<br/>    provider_id   = string<br/>    domain        = string<br/>    issuer        = string<br/>    client_id     = string<br/>    public_client = bool<br/>    client_secret = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs for bring-your-own VPC. Auto-tagged for Karpenter discovery. | `list(string)` | `[]` | no |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | Public subnet IDs for bring-your-own VPC. Auto-tagged for ALB discovery. | `list(string)` | `[]` | no |
| <a name="input_registry"></a> [registry](#input\_registry) | OCI registry to pull the chart from. Only required when enable\_ecr\_pull\_through is false. | `string` | `null` | no |
| <a name="input_s3_bucket_name_prefix"></a> [s3\_bucket\_name\_prefix](#input\_s3\_bucket\_name\_prefix) | Prefix for the generated S3 bucket name used by cake-agents object storage. When null, a prefix is generated from name. | `string` | `null` | no |
| <a name="input_s3_force_destroy"></a> [s3\_force\_destroy](#input\_s3\_force\_destroy) | Whether to force-destroy the cake-agents S3 bucket even when it contains objects. | `bool` | `false` | no |
| <a name="input_s3_prefix"></a> [s3\_prefix](#input\_s3\_prefix) | Prefix inside the S3 bucket used by cake-agents. | `string` | `"sessions"` | no |
| <a name="input_slack"></a> [slack](#input\_slack) | Optional Slack credentials for the cake-agents Helm chart. | <pre>object({<br/>    signing_secret = string<br/>    bot_token      = string<br/>  })</pre> | `null` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for a new VPC. Mutually exclusive with vpc\_id. | `string` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing VPC ID. When set, also provide private\_subnet\_ids and public\_subnet\_ids. Mutually exclusive with vpc\_cidr. | `string` | `null` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Existing Route53 hosted zone ID for hostname. If null, a new zone is created (and you must delegate it from the parent zone — see the nameservers output). | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_acm_validation_records"></a> [acm\_validation\_records](#output\_acm\_validation\_records) | ACM validation CNAMEs (informational — already created in the managed zone). Null when bringing your own zone. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | EKS cluster API endpoint. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS cluster name. |
| <a name="output_hostname"></a> [hostname](#output\_hostname) | Apex hostname for cake-agents. |
| <a name="output_nameservers"></a> [nameservers](#output\_nameservers) | NS records to add to your parent zone for delegation. Null when bringing your own zone. Resolves from a zone-only targeted apply, so you can delegate before the full apply. |
| <a name="output_nameservers_bind"></a> [nameservers\_bind](#output\_nameservers\_bind) | NS records in BIND zone-file format, ready to paste into the parent zone. Null when bringing your own zone. |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | ARN of the S3 bucket provisioned for cake-agents object storage. Null when S3 object storage is disabled. |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | Name of the S3 bucket provisioned for cake-agents object storage. Null when S3 object storage is disabled. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC the cluster runs in. |
<!-- END_TF_DOCS -->
