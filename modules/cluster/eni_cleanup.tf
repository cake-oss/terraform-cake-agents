# Best-effort teardown safety net for orphaned Karpenter nodes and leaked ENIs.
#
# On destroy, the Karpenter Helm release is removed early, so the Karpenter
# controller dies before it can terminate the worker nodes it launched. Those
# orphaned EC2 instances keep their VPC-CNI ENIs attached, which blocks deletion
# of the node security group and the subnets (and therefore the VPC). EKS/VPC-CNI
# can also leave detached "available" ENIs behind. Nothing owns either once the
# controller is gone, so no managed resource cleans them up.
#
# This null_resource depends ONLY on the VPC. On destroy that means the VPC waits
# for this provisioner to finish, while EKS/node teardown runs concurrently (EKS
# has no edge to this resource). The provisioner loops: it terminates this
# cluster's Karpenter instances, deletes detached cluster ENIs, and does not exit
# until no cluster-owned ENIs of any status remain in the VPC. Gating on the ENI
# count (rather than a fixed timer) is what keeps it alive through the full node
# teardown instead of quitting before the nodes have leaked anything. Everything
# is scoped to this cluster by tag, so it is safe even in a shared, bring-your-own
# VPC. The managed system node group is left to Terraform (no karpenter tag, so it
# is never terminated here); we only wait for its ENIs to clear.
resource "null_resource" "eni_cleanup" {
  count = var.enable_eni_cleanup ? 1 : 0

  # self.triggers is the only state a destroy provisioner can read. Referencing
  # local.vpc_id (which resolves to module.vpc when we create the VPC) is also
  # what creates the "VPC destroyed after this" ordering edge.
  triggers = {
    vpc_id       = local.vpc_id
    cluster_name = var.name
    region       = data.aws_region.current.region
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    environment = {
      VPC_ID       = self.triggers.vpc_id
      CLUSTER_NAME = self.triggers.cluster_name
      AWS_REGION   = self.triggers.region
    }
    command = <<-EOT
      set -uo pipefail

      if ! command -v aws >/dev/null 2>&1; then
        echo "eni-cleanup: aws CLI not found; skipping" >&2
        exit 0
      fi

      deadline=$(( SECONDS + 1200 ))  # 20m hard cap; overlaps EKS/node teardown
      clear_polls=0

      while :; do
        # Terminate this cluster's Karpenter nodes. Their controller is already
        # gone on destroy, so nothing else will. The managed system node group is
        # untagged here and left to Terraform. instance-state filter excludes
        # already-terminating/terminated instances.
        instances=$(aws ec2 describe-instances \
          --region "$AWS_REGION" \
          --filters \
            "Name=vpc-id,Values=$VPC_ID" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
            "Name=tag-key,Values=karpenter.sh/nodepool" \
          --query 'Reservations[].Instances[].InstanceId' \
          --output text 2>/dev/null || true)

        if [ -n "$instances" ]; then
          echo "eni-cleanup: terminating orphaned Karpenter instances: $instances" >&2
          aws ec2 terminate-instances \
            --region "$AWS_REGION" \
            --instance-ids $instances >/dev/null 2>&1 \
            || echo "eni-cleanup: terminate-instances call failed; will retry" >&2
        fi

        # Delete detached (available) cluster ENIs. Attached ones clear when their
        # instance terminates; this mops up the ones that leak as "available".
        avail=$(aws ec2 describe-network-interfaces \
          --region "$AWS_REGION" \
          --filters \
            "Name=vpc-id,Values=$VPC_ID" \
            "Name=status,Values=available" \
            "Name=tag:cluster.k8s.amazonaws.com/name,Values=$CLUSTER_NAME" \
          --query 'NetworkInterfaces[].NetworkInterfaceId' \
          --output text 2>/dev/null || true)

        for eni in $avail; do
          echo "eni-cleanup: deleting detached ENI $eni" >&2
          aws ec2 delete-network-interface \
            --region "$AWS_REGION" \
            --network-interface-id "$eni" 2>/dev/null \
            || echo "eni-cleanup: could not delete $eni (now in use?); skipping" >&2
        done

        # Exit only once NO cluster-owned ENIs of any status remain in the VPC:
        # in-use ones mean nodes (Karpenter or the managed group) are still up, so
        # keep waiting. Require two consecutive clear polls to avoid a race.
        remaining=$(aws ec2 describe-network-interfaces \
          --region "$AWS_REGION" \
          --filters \
            "Name=vpc-id,Values=$VPC_ID" \
            "Name=tag:cluster.k8s.amazonaws.com/name,Values=$CLUSTER_NAME" \
          --query 'NetworkInterfaces[].NetworkInterfaceId' \
          --output text 2>/dev/null || true)

        if [ -z "$remaining" ] && [ -z "$instances" ]; then
          clear_polls=$(( clear_polls + 1 ))
          if [ "$clear_polls" -ge 2 ]; then
            echo "eni-cleanup: no cluster ENIs or Karpenter nodes remaining" >&2
            break
          fi
        else
          clear_polls=0
        fi

        if [ "$SECONDS" -ge "$deadline" ]; then
          echo "eni-cleanup: timeout reached; leaving remainder to terraform" >&2
          break
        fi

        sleep 15
      done
    EOT
  }

  depends_on = [module.vpc]
}
