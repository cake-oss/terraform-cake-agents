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

  depends_on = [module.eks]
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

  depends_on = [
    module.karpenter,
    module.eks.eks_managed_node_groups,
    # Keep the VPC (subnets, NAT, routes) alive until Karpenter has drained and
    # terminated its out-of-band EC2 nodes. Those nodes' ENIs sit in the private
    # subnets; the references in this module only pin aws_vpc.this, so without
    # this edge Terraform can delete subnets/IGW while node ENIs still exist,
    # blocking VPC teardown.
    module.vpc,
  ]
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

  depends_on = [
    helm_release.karpenter,
    module.karpenter,
  ]
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

  depends_on = [
    kubectl_manifest.karpenter_ec2nodeclass,
    module.karpenter,
    # Destroy ordering: the NodePool must be torn down before this waiter (which
    # is in turn torn down before helm_release.karpenter). See the waiter below.
    null_resource.karpenter_drain,
  ]
}

# Graceful teardown gate: give Karpenter time to drain and terminate the nodes it
# launched BEFORE its controller is uninstalled.
#
# On destroy Terraform deletes kubectl_manifest.karpenter_nodepool first (it
# depends on this waiter, so it is destroyed before it). Deleting the NodePool
# cascades via ownerReferences to its NodeClaims, whose Karpenter finalizers
# cordon, drain, and terminate the backing EC2 instances. This waiter then blocks
# until no Karpenter-owned instances remain, and only then is
# helm_release.karpenter (which this waiter depends on) uninstalled. Without this
# gate the controller is removed within seconds of the NodePool deletion, leaving
# its half-drained nodes orphaned with attached ENIs that block node SG and subnet
# teardown. If the graceful drain stalls (e.g. the controller is unhealthy), this
# waiter force-terminates the stragglers itself once a grace period elapses. It is
# ordered after the cake-agents ingress (which depends on the NodePool), so even a
# force-terminate here cannot yank an ALB target mid teardown.
resource "null_resource" "karpenter_drain" {
  count = var.enable_karpenter_drain ? 1 : 0

  triggers = {
    cluster_name = var.name
    region       = data.aws_region.current.region
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    environment = {
      CLUSTER_NAME = self.triggers.cluster_name
      AWS_REGION   = self.triggers.region
    }
    command = <<-EOT
      set -uo pipefail

      if ! command -v aws >/dev/null 2>&1; then
        echo "karpenter-drain: aws CLI not found; skipping" >&2
        exit 0
      fi

      deadline=$(( SECONDS + 600 ))  # 10m hard cap
      force_after=300                # let Karpenter drain gracefully for 5m first
      clear_polls=0

      while :; do
        # This cluster's Karpenter nodes. shutting-down is included so we wait out
        # in-progress terminations rather than exiting while they finish. The
        # managed system node group has no karpenter.sh/nodepool tag, so it is not
        # counted here (Terraform tears it down separately).
        instances=$(aws ec2 describe-instances \
          --region "$AWS_REGION" \
          --filters \
            "Name=tag:eks:eks-cluster-name,Values=$CLUSTER_NAME" \
            "Name=tag-key,Values=karpenter.sh/nodepool" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" \
          --query 'Reservations[].Instances[].InstanceId' \
          --output text 2>/dev/null || true)

        if [ -z "$instances" ]; then
          # Two consecutive clear polls to avoid racing the cascade GC that has
          # not yet created the NodeClaim deletions.
          clear_polls=$(( clear_polls + 1 ))
          if [ "$clear_polls" -ge 2 ]; then
            echo "karpenter-drain: all Karpenter nodes drained" >&2
            break
          fi
        else
          clear_polls=0
          if [ "$SECONDS" -ge "$force_after" ]; then
            # Graceful drain has stalled past the grace period; force-terminate.
            # Safe here: the ingress/ALB is already gone by this point.
            echo "karpenter-drain: grace elapsed; force-terminating: $instances" >&2
            aws ec2 terminate-instances \
              --region "$AWS_REGION" \
              --instance-ids $instances >/dev/null 2>&1 \
              || echo "karpenter-drain: terminate-instances failed; will retry" >&2
          else
            echo "karpenter-drain: waiting for Karpenter to terminate: $instances" >&2
          fi
        fi

        if [ "$SECONDS" -ge "$deadline" ]; then
          echo "karpenter-drain: timeout; leaving remainder to terraform" >&2
          break
        fi

        sleep 15
      done
    EOT
  }

  depends_on = [helm_release.karpenter]
}
