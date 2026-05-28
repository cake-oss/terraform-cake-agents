data "aws_availability_zones" "available" {
  count = local.create_vpc ? 1 : 0

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs             = local.create_vpc ? slice(data.aws_availability_zones.available[0].names, 0, 3) : []
  private_subnets = local.create_vpc ? [for k, _ in local.azs : cidrsubnet(var.vpc_cidr, 2, k)] : []
  public_subnets  = local.create_vpc ? [for k, _ in local.azs : cidrsubnet(var.vpc_cidr, 6, k + 48)] : []
}

module "vpc" {
  count = local.create_vpc ? 1 : 0

  source  = "terraform-aws-modules/vpc/aws"
  version = "6.2.0"

  name = "${var.name}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = !var.nat_gateway_per_az
  enable_dns_hostnames = true

  private_subnet_tags = {
    "karpenter.sh/discovery"          = var.name
    "kubernetes.io/role/internal-elb" = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

# Auto-tag user-supplied subnets so Karpenter and the AWS Load Balancer
# Controller can discover them. No-ops when creating a new VPC.
resource "aws_ec2_tag" "private_subnet_karpenter" {
  for_each = local.create_vpc ? toset([]) : toset(var.private_subnet_ids)

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.name
}

resource "aws_ec2_tag" "private_subnet_internal_elb" {
  for_each = local.create_vpc ? toset([]) : toset(var.private_subnet_ids)

  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "public_subnet_elb" {
  for_each = local.create_vpc ? toset([]) : toset(var.public_subnet_ids)

  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}
