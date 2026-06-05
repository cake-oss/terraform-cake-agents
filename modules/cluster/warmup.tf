# Warm the pull-through cache for the cake-agents chart before the Helm
# provider tries to install it. The cache populates lazily and the first
# fetch is async; the Helm provider fails fast if the chart isn't ready.
# Retries with exponential backoff give the import enough time to land.
#
# Requires `helm` and `aws` CLIs on the machine running terraform apply.
# Triggered by chart_version, so a version bump re-runs the pull.

resource "null_resource" "warmup_chart" {
  count = var.enable_ecr_pull_through ? 1 : 0

  triggers = {
    chart_version = var.cake_agents_chart_version
    registry      = local.chart_registry
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      REGION=${data.aws_region.current.region}
      REGISTRY_HOST=${local.registry_host}
      CHART_REF=oci://$REGISTRY_HOST/${local.pull_through_chart}
      aws ecr get-login-password --region "$REGION" \
        | helm registry login --username AWS --password-stdin "$REGISTRY_HOST"
      attempt=1
      max_attempts=10
      delay=5
      until helm pull "$CHART_REF" --version "${var.cake_agents_chart_version}" --destination "$(mktemp -d)"; do
        if [ "$attempt" -ge "$max_attempts" ]; then
          echo "helm pull failed after $attempt attempts" >&2
          exit 1
        fi
        echo "helm pull attempt $attempt failed; retrying in $${delay}s" >&2
        sleep "$delay"
        attempt=$((attempt + 1))
        delay=$(( delay * 2 < 30 ? delay * 2 : 30 ))
      done
    EOT
  }

  depends_on = [
    aws_ecr_pull_through_cache_rule.cake_agents,
    aws_iam_role_policy.pull_through_cache,
  ]
}
