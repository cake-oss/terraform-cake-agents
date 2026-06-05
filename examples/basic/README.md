# Basic example

Single-apply deployment of cake-agents with a new VPC and a new Route53 zone.

## Prerequisites

- AWS credentials with permission to apply the root module (see `modules/deploy-role` for the required IAM policies)
- `helm` and `aws` CLIs available locally (used to warm the ECR pull-through cache)
- Control of the parent DNS zone for `var.hostname` so you can delegate the child zone

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars

terraform init
terraform apply
```

First apply will hang on ACM cert validation until you delegate the child zone. The `nameservers` output lists the NS records — add those in your parent zone, then let the apply continue (it polls until validation succeeds).

If validation times out, re-run `terraform apply`.
