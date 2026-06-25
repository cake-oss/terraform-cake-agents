module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.3.2"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  endpoint_private_access      = true
  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["0.0.0.0/0"]

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  enabled_log_types = ["audit", "api", "authenticator", "controllerManager", "scheduler"]

  # Envelope-encrypt Kubernetes secrets in etcd with a per-cluster CMK.
  # The EKS module's v21 default is the AWS-managed aws/eks key, which can't
  # be rotated or audited independently.
  create_kms_key = true
  encryption_config = {
    resources = ["secrets"]
  }
  kms_key_administrators  = local.kms_admin_principals
  enable_kms_key_rotation = true

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  access_entries = (local.sso_admin_arn == "" || local.caller_is_sso_admin) ? {} : {
    sso_admin = {
      principal_arn = local.sso_admin_arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  enable_irsa = false

  addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    metrics-server         = {}
    vpc-cni = {
      before_compute = true
      # IP-level warming instead of whole-ENI warming. WARM_ENI_TARGET=0 stops
      # vpc-cni from pre-attaching a spare ENI per node; those spares get
      # detached when the warm pool shrinks and then leak as "available" ENIs
      # that block subnet deletion on teardown (nothing owns them once the node
      # is gone). Warming individual IPs avoids creating them and conserves
      # subnet IP space.
      configuration_values = jsonencode({
        env = {
          WARM_ENI_TARGET   = "0"
          WARM_IP_TARGET    = "5"
          MINIMUM_IP_TARGET = "10"
        }
      })
    }
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = aws_iam_role.ebs_csi.arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.name
  }

  # The metrics-server addon (v0.8.x) serves on 10251; the module's default node
  # SG rules only open the control-plane webhook ports (incl. the old 4443) and
  # kubelet 10250, so the aggregation layer can't reach metrics-server and the
  # metrics.k8s.io APIService stays FailedDiscoveryCheck. That breaks `kubectl
  # top`/HPAs and makes every namespace deletion's discovery sweep fail. Open
  # 10251 from the cluster security group to fix it.
  node_security_group_additional_rules = {
    metrics_server = {
      description                   = "Cluster API to metrics-server (10251)"
      protocol                      = "tcp"
      from_port                     = 10251
      to_port                       = 10251
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # The system node group runs Karpenter itself on cheap arm64 instances.
  # Workload nodes provisioned by Karpenter use amd64 (see karpenter.tf).
  eks_managed_node_groups = {
    system = {
      ami_type       = "BOTTLEROCKET_ARM_64"
      instance_types = ["t4g.medium"]

      min_size     = 2
      max_size     = 3
      desired_size = 2

      labels = {
        "karpenter.sh/controller" = "true"
      }

      taints = {
        karpenter = {
          key    = "karpenter.sh/controller"
          value  = "true"
          effect = "PREFER_NO_SCHEDULE"
        }
        critical = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      iam_role_additional_policies = var.enable_ecr_pull_through ? {
        ecr_pull_through = aws_iam_policy.node_ecr_pull_through[0].arn
      } : {}
    }
  }
}
