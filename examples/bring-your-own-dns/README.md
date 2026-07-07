# Bring your own DNS example

Single-apply deployment of cake-agents with a new VPC and your own DNS instead of a Cake-managed `cakeagents.ai` hostname.

This example serves cake-agents at `https://demo.cake.ai`. It uses [`modules/dns`](../../modules/dns/) to create a Route53 hosted zone for `demo.cake.ai` and a DNS-validated ACM certificate. You delegate that child zone from wherever the parent domain is managed; this example does **not** assume the parent zone is in the same AWS account or even in Route53.

## Prerequisites

- AWS credentials with permission to apply the root module (see `modules/deploy-role` for the required IAM policies)
- `aws` CLI available locally
- Ability to add NS records for `demo.cake.ai` in the DNS provider that manages the parent domain

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set name and region
# hostname defaults to demo.cake.ai; vpc_cidr defaults to 10.0.0.0/16

terraform init
```

### 1. Create only the hosted zone and export its nameservers

Create the child Route53 hosted zone first:

```bash
terraform apply -target=module.dns.aws_route53_zone.this
```

Then export the nameservers:

```bash
terraform output nameservers
# or, for BIND-style zone-file records:
terraform output nameservers_bind
```

Add those NS records for `demo.cake.ai` wherever the parent DNS zone is managed. Wait for delegation to propagate before continuing.

### 2. Apply the full deployment

```bash
terraform apply
```

Terraform will then:

1. Create DNS validation records in the `demo.cake.ai` child zone.
2. Validate the ACM certificate for `demo.cake.ai`.
3. Deploy cake-agents without an `install_key` and without requesting a `cakeagents.ai` hostname.
4. Create a Route53 alias A record for `demo.cake.ai` pointing at the cake-agents ALB.

If ACM validation times out, confirm the parent DNS delegates `demo.cake.ai` to the nameservers from `terraform output nameservers`, then re-run `terraform apply`.
