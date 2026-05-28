# Least-privilege IAM policies for terraform applies of the root module,
# split along the optional-component boundaries of the root module so
# users with BYO VPC or BYO DNS can attach only what they need.
#
# Policies (always created):
# - <name>-required: always needed — EKS, RDS, KMS, IAM, ECR, security
#                    groups, launch templates, CloudWatch logs, SSM AMI
#                    lookups, ELB read, and Route53 record-level perms for
#                    the apex alias.
# - <name>-vpc:      VPC creation perms (CreateVpc, subnets, route tables,
#                    NAT, IGW, EIPs, network ACLs). Only needed when the
#                    root module creates the VPC (var.vpc_cidr set).
# - <name>-dns:      Route53 zone + ACM cert lifecycle. Only needed when
#                    the root module creates the zone (var.zone_id null).
#
# Role (created when create_role = true):
# - <name>: trusts var.assume_role_principals/conditions, always has the
#           required policy attached, and additionally attaches any of
#           the optional policies in var.attach_optional_policies.

data "aws_caller_identity" "current" {}

############
# required #
############

resource "aws_iam_policy" "required" {
  name        = "${var.name}-required"
  description = "Permissions to apply the terraform-cake-agents root module (cluster + IAM + ECR + Route53 records)"
  policy      = data.aws_iam_policy_document.required.json
}

data "aws_iam_policy_document" "required" {
  statement {
    sid = "EC2BaseAccess"
    actions = [
      "ec2:Describe*",
      "ec2:GetSecurityGroupsForVpc",
      # Tagging covers BYO subnet auto-tagging for Karpenter/ALB discovery
      # as well as tagging on cluster-managed resources.
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "EKSNodeGroupLaunchTemplate"
    actions   = ["ec2:RunInstances"]
    resources = ["*"]
  }

  statement {
    sid = "ELBv2Read"
    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeTags",
    ]
    resources = ["*"]
  }

  statement {
    sid = "RDS"
    actions = [
      "rds:CreateDBInstance",
      "rds:DeleteDBInstance",
      "rds:ModifyDBInstance",
      "rds:RebootDBInstance",
      "rds:DescribeDBInstances",
      "rds:CreateDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:ModifyDBSubnetGroup",
      "rds:DescribeDBSubnetGroups",
      "rds:CreateDBParameterGroup",
      "rds:DeleteDBParameterGroup",
      "rds:ModifyDBParameterGroup",
      "rds:DescribeDBParameterGroups",
      "rds:DescribeDBParameters",
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource",
      "rds:ListTagsForResource",
      "rds:DescribeDBEngineVersions",
      "rds:DescribeDBSnapshots",
    ]
    resources = ["*"]
  }

  statement {
    sid = "SecurityGroups"
    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:ModifySecurityGroupRules",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
      "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
    ]
    resources = ["*"]
  }

  statement {
    sid = "LaunchTemplates"
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:DeleteLaunchTemplate",
      "ec2:ModifyLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:DeleteLaunchTemplateVersion",
      "ec2:GetLaunchTemplateData",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "EKS"
    actions   = ["eks:*"]
    resources = ["*"]
  }

  statement {
    sid = "EKSClusterLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:ListTagsForResource",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "KMS"
    actions = [
      "kms:CreateKey",
      "kms:DescribeKey",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:EnableKeyRotation",
      "kms:DisableKeyRotation",
      "kms:GetKeyRotationStatus",
      "kms:GetKeyPolicy",
      "kms:PutKeyPolicy",
      "kms:ListAliases",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:UpdateAlias",
      "kms:ListResourceTags",
      "kms:TagResource",
      "kms:UntagResource",
      # Required so AWS can create service grants on the customer-managed
      # keys when launching EKS clusters and RDS instances configured for
      # envelope/storage encryption.
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
      "kms:RetireGrant",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "SSMReadPublicAMIParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:*::parameter/aws/service/*"]
  }

  statement {
    sid = "Route53Records"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:GetChange",
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
    ]
    resources = ["*"]
  }

  statement {
    sid = "IAM"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateOpenIDConnectProvider",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:CreateServiceLinkedRole",
      "iam:CreateInstanceProfile",
      "iam:DeleteOpenIDConnectProvider",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DeleteInstanceProfile",
      "iam:DetachRolePolicy",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListOpenIDConnectProviders",
      "iam:ListPolicies",
      "iam:ListPolicyTags",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
      "iam:ListRoleTags",
      "iam:ListRoles",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:SetDefaultPolicyVersion",
      "iam:TagOpenIDConnectProvider",
      "iam:TagPolicy",
      "iam:TagRole",
      "iam:UntagPolicy",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ECRPullThroughCache"
    actions = [
      "ecr:CreatePullThroughCacheRule",
      "ecr:DeletePullThroughCacheRule",
      "ecr:DescribePullThroughCacheRules",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ECRAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ECRPull"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      # BatchImportUpstreamImage + CreateRepository together trigger the
      # pull-through cache to fetch and cache an upstream image on first pull.
      # The warmup null_resource runs `helm pull` as the deploy principal.
      "ecr:BatchImportUpstreamImage",
      "ecr:CreateRepository",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
      "ecr:ListImages",
    ]
    resources = ["arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/*"]
  }
}

#######
# vpc #
#######

resource "aws_iam_policy" "vpc" {
  name        = "${var.name}-vpc"
  description = "Permissions to create the VPC and its supporting networking when var.vpc_cidr is set on the root module"
  policy      = data.aws_iam_policy_document.vpc.json
}

data "aws_iam_policy_document" "vpc" {
  statement {
    sid = "VPCNetworking"
    actions = [
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:ModifySubnetAttribute",
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:ReplaceRoute",
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:DisassociateAddress",
      "ec2:CreateNetworkAcl",
      "ec2:DeleteNetworkAcl",
      "ec2:CreateNetworkAclEntry",
      "ec2:DeleteNetworkAclEntry",
      "ec2:ReplaceNetworkAclEntry",
      "ec2:ReplaceNetworkAclAssociation",
    ]
    resources = ["*"]
  }
}

#######
# dns #
#######

resource "aws_iam_policy" "dns" {
  name        = "${var.name}-dns"
  description = "Permissions to create the Route53 hosted zone and ACM certificate when var.zone_id is null on the root module"
  policy      = data.aws_iam_policy_document.dns.json
}

data "aws_iam_policy_document" "dns" {
  statement {
    sid = "Route53Zones"
    actions = [
      "route53:CreateHostedZone",
      "route53:DeleteHostedZone",
      "route53:AssociateVPCWithHostedZone",
      "route53:DisassociateVPCFromHostedZone",
      "route53:ListHostedZonesByName",
      "route53:UpdateHostedZoneComment",
      "route53:ChangeTagsForResource",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ACMCertificates"
    actions = [
      "acm:RequestCertificate",
      "acm:DeleteCertificate",
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:ListTagsForCertificate",
      "acm:AddTagsToCertificate",
      "acm:RemoveTagsFromCertificate",
      "acm:UpdateCertificateOptions",
    ]
    resources = ["*"]
  }
}

##############
# role glue #
##############

locals {
  policy_arns = {
    required = aws_iam_policy.required.arn
    vpc      = aws_iam_policy.vpc.arn
    dns      = aws_iam_policy.dns.arn
  }
  policy_jsons = {
    required = data.aws_iam_policy_document.required.json
    vpc      = data.aws_iam_policy_document.vpc.json
    dns      = data.aws_iam_policy_document.dns.json
  }
}

data "aws_iam_policy_document" "assume" {
  count = var.create_role ? 1 : 0

  dynamic "statement" {
    for_each = var.assume_role_statements
    content {
      actions = ["sts:AssumeRole", "sts:AssumeRoleWithWebIdentity", "sts:TagSession"]

      dynamic "principals" {
        for_each = statement.value.principals
        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_iam_role" "deploy" {
  count = var.create_role ? 1 : 0

  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume[0].json
}

locals {
  attached_policy_keys = var.create_role ? toset(concat(["required"], var.attach_optional_policies)) : toset([])
}

resource "aws_iam_role_policy_attachment" "deploy" {
  for_each = local.attached_policy_keys

  role       = aws_iam_role.deploy[0].name
  policy_arn = local.policy_arns[each.value]
}
