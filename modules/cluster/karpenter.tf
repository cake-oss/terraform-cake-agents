# Karpenter is the autoscaler for this cluster. Every other Kubernetes
# resource in this module declares depends_on against helm_release.karpenter
# so it isn't applied before a working node provisioner exists. The system
# node group runs Karpenter itself; everything else relies on Karpenter to
# bring up workload nodes (or to fall back onto the system pool gracefully).

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.3.2"

  cluster_name = module.eks.cluster_name
  namespace    = "karpenter"

  enable_spot_termination = false

  node_iam_role_additional_policies = var.enable_ecr_pull_through ? {
    ecr_pull_through = aws_iam_policy.node_ecr_pull_through[0].arn
  } : {}
}

resource "helm_release" "karpenter" {
  namespace        = module.karpenter.namespace
  create_namespace = true
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.9.0"
  wait             = true

  values = [yamlencode({
    settings = {
      clusterName     = module.eks.cluster_name
      clusterEndpoint = module.eks.cluster_endpoint
    }
    nodeSelector = {
      "karpenter.sh/controller" = "true"
    }
    tolerations = [
      { key = "CriticalAddonsOnly", operator = "Exists", effect = "NoSchedule" },
      { key = "karpenter.sh/controller", operator = "Exists", effect = "PreferNoSchedule" },
    ]
    serviceAccount = {
      name = module.karpenter.service_account
    }
  })]

  depends_on = [module.eks.eks_managed_node_groups]
}

resource "kubectl_manifest" "karpenter_ec2nodeclass" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata   = { name = "default" }
    spec = {
      amiSelectorTerms = [{ alias = "al2023@latest" }]
      role             = module.karpenter.node_iam_role_name
      subnetSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.name } },
      ]
      securityGroupSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.name } },
      ]
      metadataOptions = {
        httpEndpoint            = "enabled"
        httpProtocolIPv6        = "disabled"
        httpPutResponseHopLimit = 1
        httpTokens              = "required"
      }
    }
  })

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "karpenter_nodepool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "default" }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            { key = "karpenter.k8s.aws/instance-family", operator = "In", values = ["m5", "m6i", "m7i"] },
            { key = "karpenter.k8s.aws/instance-cpu", operator = "In", values = ["4", "8", "16", "32"] },
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
          ]
          expireAfter = "720h"
        }
      }
      limits = {
        cpu    = "1000"
        memory = "1000Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
      }
    }
  })

  depends_on = [kubectl_manifest.karpenter_ec2nodeclass]
}
