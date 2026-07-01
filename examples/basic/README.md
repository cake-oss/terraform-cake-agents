# Basic example

Single-apply deployment of cake-agents with a new VPC and Cake-hosted DNS automation.

## Prerequisites

- AWS credentials with permission to apply the root module (see `modules/deploy-role` for the required IAM policies)
- `aws` CLI available locally
- A Cake install key (`install_key`) for DNS automation, available from https://console.cake.ai

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and add your install_key from https://console.cake.ai
# also set name and region; cake_agents_chart_version defaults to the pinned version in this module
# vpc_cidr defaults to 10.0.0.0/16 — change it if you'll peer this VPC with a conflicting range

terraform init
```

### Apply

```bash
terraform apply
```

This provisions the cluster, supporting infrastructure, and the cake-agents Helm
release, then waits for ACM validation records created through Cake-hosted DNS.
If ACM validation times out, confirm your `install_key` is valid and re-run
`terraform apply`.
