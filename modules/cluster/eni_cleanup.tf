# Best-effort teardown safety net for leaked ENIs.
#
# EKS/VPC-CNI can leave "available" (detached) ENIs behind in the cluster VPC
# when nodes terminate. Nothing owns them once the node is gone, so they aren't
# deleted by any managed resource and they block subnet (and therefore VPC)
# deletion at the end of a destroy.
#
# This null_resource depends ONLY on the VPC. On destroy that means the VPC
# waits for this provisioner to finish, while EKS/node teardown runs
# concurrently (EKS has no edge to this resource). The provisioner polls in a
# loop, deleting orphaned ENIs as nodes release them, right up until the VPC is
# torn down. Deletions are scoped to this cluster via the VPC-CNI ownership tag,
# so it is safe even in a shared, bring-your-own VPC.
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

      deadline=$(( SECONDS + 900 ))  # up to 15m; overlaps EKS/node teardown
      min_runtime=120                # don't quit before nodes can release ENIs
      empty_polls=0

      while :; do
        enis=$(aws ec2 describe-network-interfaces \
          --region "$AWS_REGION" \
          --filters \
            "Name=vpc-id,Values=$VPC_ID" \
            "Name=status,Values=available" \
            "Name=tag:cluster.k8s.amazonaws.com/name,Values=$CLUSTER_NAME" \
          --query 'NetworkInterfaces[].NetworkInterfaceId' \
          --output text 2>/dev/null || true)

        if [ -n "$enis" ]; then
          empty_polls=0
          for eni in $enis; do
            echo "eni-cleanup: deleting orphaned ENI $eni" >&2
            aws ec2 delete-network-interface \
              --region "$AWS_REGION" \
              --network-interface-id "$eni" 2>/dev/null \
              || echo "eni-cleanup: could not delete $eni (now in use?); skipping" >&2
          done
        else
          empty_polls=$(( empty_polls + 1 ))
        fi

        # Settle: a few consecutive empty polls, but never before min_runtime so
        # we don't exit before EKS has had a chance to release its ENIs.
        if [ "$empty_polls" -ge 3 ] && [ "$SECONDS" -ge "$min_runtime" ]; then
          echo "eni-cleanup: no orphaned ENIs remaining" >&2
          break
        fi

        if [ "$SECONDS" -ge "$deadline" ]; then
          echo "eni-cleanup: timeout reached; leaving remaining ENIs to terraform" >&2
          break
        fi

        sleep 15
      done
    EOT
  }

  depends_on = [module.vpc]
}
