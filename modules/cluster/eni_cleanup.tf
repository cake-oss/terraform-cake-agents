# Best-effort teardown safety net for leaked ENIs.
#
# EKS/VPC-CNI can leave detached "available" ENIs behind in the cluster VPC when
# nodes terminate. Nothing owns them once the node is gone, so no managed resource
# deletes them, and they block subnet (and therefore VPC) deletion.
#
# This is ENI-only on purpose: it does NOT terminate instances. Node teardown is
# handled gracefully and in the right order elsewhere — Karpenter's own nodes by
# null_resource.karpenter_drain (which is sequenced after the ingress so the ALB
# teardown isn't disrupted), and the managed system node group by Terraform. An
# eager terminate here runs at the very start of destroy and would kill workload
# nodes out from under the in-flight ALB/target-group teardown, so we only sweep
# detached ENIs and wait for the nodes to go away on their own.
#
# This null_resource depends ONLY on the VPC. On destroy that means the VPC waits
# for this provisioner to finish while EKS/node teardown runs concurrently (EKS
# has no edge to this resource). The loop deletes detached cluster ENIs and does
# not exit until no cluster-owned ENIs of any status remain in the VPC, so it
# naturally waits out the full node teardown before letting the subnets delete.
# Everything is scoped to this cluster by tag, so it is safe in a shared,
# bring-your-own VPC.
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
        # Delete detached (available) cluster ENIs. Attached ones clear when their
        # node terminates; this mops up the ones that leak as "available".
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

        if [ -z "$remaining" ]; then
          clear_polls=$(( clear_polls + 1 ))
          if [ "$clear_polls" -ge 2 ]; then
            echo "eni-cleanup: no cluster ENIs remaining" >&2
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
