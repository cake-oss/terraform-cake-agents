# Basic example

Single-apply deployment of cake-agents with a new VPC and Cake-hosted DNS automation.

## Prerequisites

- AWS credentials with permission to apply the root module (see `modules/deploy-role` for the required IAM policies)
- `helm` and `aws` CLIs available locally (used to warm the ECR pull-through cache)
- A Cake install key (`install_key`) for DNS automation

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit name, region, cake_agents_chart_version, install_key
# vpc_cidr defaults to 10.0.0.0/16 — change it if you'll peer this VPC with a conflicting range

terraform init
```

The apply is staged only for ECR cache warm-up.

### 1. Warm the ECR pull-through cache

The cache populates lazily and the first chart fetch is async, so the Helm
provider fails fast if the chart isn't ready. Warm it before the full apply:

```bash
terraform apply -target='module.cake_agents.module.cluster.null_resource.warmup_chart'
```

Skip this step if you've set `enable_ecr_pull_through = false`.

### 2. Apply

```bash
terraform apply
```

This provisions the cluster, supporting infrastructure, and the cake-agents Helm
release, then waits for ACM validation records created through Cake-hosted DNS.
If ACM validation times out, confirm your `install_key` is valid and re-run
`terraform apply`.
