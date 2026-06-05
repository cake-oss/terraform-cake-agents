# Basic example

Single-apply deployment of cake-agents with a new VPC and a new Route53 zone.

## Prerequisites

- AWS credentials with permission to apply the root module (see `modules/deploy-role` for the required IAM policies)
- `helm` and `aws` CLIs available locally (used to warm the ECR pull-through cache)
- Control of the parent DNS zone for `var.hostname` so you can delegate the child zone

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit name, hostname, region, cake_agents_chart_version
# vpc_cidr defaults to 10.0.0.0/16 — change it if you'll peer this VPC with a conflicting range

terraform init
```

The first apply is staged: delegate DNS so ACM validation can complete, warm the
ECR pull-through cache, then run the full apply.

### 1. Delegate the DNS zone (module-managed DNS)

If you let the module create the Route53 zone (the default — `zone_id` unset),
provision the zone first so you can delegate it before ACM validation blocks the
rest of the apply:

```bash
terraform apply -target='module.cake_agents.module.dns[0].aws_route53_zone.this'
terraform output nameservers        # the NS records to delegate
terraform output -raw nameservers_bind   # same records, BIND zone-file format
```

The `nameservers` output depends only on the hosted zone, so it resolves from
this zone-only apply. Use `nameservers_bind` if your parent zone is managed as a
BIND zone file — it's ready to paste in. **Add those as NS records in your parent (upstream) DNS
zone before continuing.** Delegation must resolve or ACM validation in the full
apply will hang. Skip this step entirely if you bring your own zone (`zone_id`
set).

### 2. Warm the ECR pull-through cache

The cache populates lazily and the first chart fetch is async, so the Helm
provider fails fast if the chart isn't ready. Warm it before the full apply:

```bash
terraform apply -target='module.cake_agents.module.cluster.null_resource.warmup_chart'
```

Skip this step if you've set `enable_ecr_pull_through = false`.

### 3. Apply

```bash
terraform apply
```

This provisions the cluster, supporting infrastructure, and the cake-agents Helm
release, then polls until ACM validation lands. If it times out waiting on DNS,
confirm the NS delegation from step 1 has propagated and re-run `terraform apply`.
