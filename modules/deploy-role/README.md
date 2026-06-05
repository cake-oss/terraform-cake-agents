# modules/deploy-role

IAM policies (and an optional role) for principals that apply the root module — e.g. a GitHub Actions OIDC role, Spacelift, env0, or a long-lived CI user.

The permissions are split along the same optional-component boundaries as the root module, so users who bring their own VPC or DNS can attach only what they need:

| Policy | AWS name | Always attached? | When needed |
| --- | --- | :---: | --- |
| `required` | `<var.name>-required` | yes | Always — EKS, RDS, KMS, IAM, ECR, security groups, launch templates, CloudWatch logs, SSM AMI lookups, ELB read, Route53 record-level perms for the apex alias |
| `vpc` | `<var.name>-vpc` | yes by default | Only when the root module creates the VPC (root `vpc_cidr` set) |
| `dns` | `<var.name>-dns` | yes by default | Only when the root module creates the Route53 zone + ACM cert (root `zone_id` null) |

All three policies are **always created** so they're available to attach manually later. The `attach_optional_policies` variable only controls which of `vpc` and `dns` get attached to the role this module creates.

## Two usage shapes

**Policy only** (`create_role = false`, default): outputs `policy_arns` and `policy_jsons` (each a map keyed by `required`/`vpc`/`dns`). Attach the relevant ARNs to a role you manage elsewhere.

**Policy + role** (`create_role = true`): also creates an IAM role named `<var.name>` with the trust relationship you supply in `assume_role_principals` / `assume_role_conditions`. The `required` policy is always attached; `vpc` and `dns` are attached unless removed from `attach_optional_policies`. See [`examples/github-actions`](../../examples/github-actions/) for the GitHub OIDC shape.

## Examples

BYO VPC and DNS — attach only the `required` policy to the role:

```hcl
module "deploy" {
  source      = "github.com/cake-ai/terraform-cake-agents//modules/deploy-role"
  name        = "cake-agents-deploy"
  create_role = true

  assume_role_statements = [
    {
      principals = [{
        type        = "Federated"
        identifiers = [aws_iam_openid_connect_provider.github.arn]
      }]
      conditions = [
        { test = "StringEquals", variable = "token.actions.githubusercontent.com:aud", values = ["sts.amazonaws.com"] },
        { test = "StringLike", variable = "token.actions.githubusercontent.com:sub", values = ["repo:my-org/my-repo:*"] },
      ]
    },
  ]

  attach_optional_policies = []
}
```

Multiple distinct trust patterns — e.g. GitHub Actions plus SSO admin — go in separate entries:

```hcl
assume_role_statements = [
  {
    principals = [{ type = "Federated", identifiers = [aws_iam_openid_connect_provider.github.arn] }]
    conditions = [
      { test = "StringEquals", variable = "token.actions.githubusercontent.com:aud", values = ["sts.amazonaws.com"] },
      { test = "StringLike", variable = "token.actions.githubusercontent.com:sub", values = ["repo:my-org/my-repo:*"] },
    ]
  },
  {
    principals = [{ type = "AWS", identifiers = [data.aws_iam_role.sso_admin.arn] }]
  },
]
```

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
| [aws_iam_policy.dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.required](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.deploy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.deploy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.required](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_assume_role_statements"></a> [assume\_role\_statements](#input\_assume\_role\_statements) | Trust relationship statements for the deploy role. Each entry becomes one statement in the role's assume\_role\_policy with its principals OR'd and its conditions AND'd. Multiple entries are OR'd at the policy level — use one entry per distinct trust pattern (e.g. one for GitHub Actions, one for SSO admin). Required when create\_role is true. | <pre>list(object({<br/>    principals = list(object({<br/>      type        = string<br/>      identifiers = list(string)<br/>    }))<br/>    conditions = optional(list(object({<br/>      test     = string<br/>      variable = string<br/>      values   = list(string)<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_attach_optional_policies"></a> [attach\_optional\_policies](#input\_attach\_optional\_policies) | Which of the optional split policies to attach to the role (the required policy is always attached). Drop "vpc" for BYO VPC. Drop "dns" for BYO Route53 zone + ACM certificate. All three policies are still created — this only controls attachment. | `list(string)` | <pre>[<br/>  "vpc",<br/>  "dns"<br/>]</pre> | no |
| <a name="input_create_role"></a> [create\_role](#input\_create\_role) | When true, create an IAM role with the trust relationship from assume\_role\_principals/conditions and attach the required policy (plus any optional policies in attach\_optional\_policies). When false, only the three policies are created and you attach the ones you need to a role you manage. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Base name for IAM resources. The required policy is created as `<name>-required`; optional policies are `<name>-vpc` and `<name>-dns`. The role (when create\_role = true) is named `<name>`. | `string` | `"cake-agents-deploy"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_policy_arns"></a> [policy\_arns](#output\_policy\_arns) | Map of policy ARNs keyed by purpose: required (always needed), vpc (only when the root module creates the VPC), dns (only when the root module creates the Route53 zone + ACM cert). |
| <a name="output_policy_jsons"></a> [policy\_jsons](#output\_policy\_jsons) | Map of policy document JSONs keyed by purpose. Useful for embedding in externally-managed policies. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the deploy role. Null when create\_role is false. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the deploy role. Null when create\_role is false. |
<!-- END_TF_DOCS -->
