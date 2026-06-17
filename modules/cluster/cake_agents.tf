resource "kubernetes_namespace_v1" "cake_agents" {
  metadata {
    name = "cake-agents"
  }
}

resource "random_password" "cake_agents_db" {
  length           = 32
  special          = true
  override_special = "_-"
}

resource "kubernetes_secret_v1" "cake_agents_db_creds" {
  metadata {
    name      = "cake-agents-db-creds"
    namespace = kubernetes_namespace_v1.cake_agents.metadata[0].name
  }

  data = {
    connection_string = "postgresql://${module.cake_agents_db.db_instance_username}:${urlencode(random_password.cake_agents_db.result)}@${module.cake_agents_db.db_instance_endpoint}/${module.cake_agents_db.db_instance_name}?sslmode=require"
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "cake_agents_oidc_creds" {
  count = var.oidc != null && !var.oidc.public_client ? 1 : 0

  metadata {
    name      = "sso-oidc"
    namespace = kubernetes_namespace_v1.cake_agents.metadata[0].name
  }

  data = {
    clientSecret = var.oidc.client_secret
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "cake_agents_slack_creds" {
  count = var.slack != null ? 1 : 0

  metadata {
    name      = "slack"
    namespace = kubernetes_namespace_v1.cake_agents.metadata[0].name
  }

  data = {
    signingSecret = var.slack.signing_secret
    botToken      = var.slack.bot_token
  }

  type = "Opaque"
}

resource "helm_release" "cake_agents" {
  namespace  = kubernetes_namespace_v1.cake_agents.metadata[0].name
  name       = "cake-agents"
  repository = local.chart_registry
  chart      = "cake-agents"
  version    = var.cake_agents_chart_version
  wait       = true

  values = [yamlencode(merge(
    {
      registry = {
        # Same registry as the chart, minus the /charts subpath, so image refs
        # inside the chart resolve through the same pull-through cache.
        default = trimsuffix(trimprefix(local.chart_registry, "oci://"), "/charts")
      }
      image = {
        tag = var.cake_agents_chart_version
      }
      controlPlane = {
        host = var.hostname
        extraHosts = concat(
          var.oidc == null ? [] : [regex("^https?://([^/:]+)", var.oidc.issuer)[0]],
          var.extra_hosts,
        )
      }
      pathPrefix = "/"
      postgresql = {
        enabled = false
      }
      externalDatabase = {
        existingSecret    = kubernetes_secret_v1.cake_agents_db_creds.metadata[0].name
        existingSecretKey = "connection_string"
      }
    },
    var.enable_s3_object_storage ? {
      s3 = {
        enabled = true
        bucket  = aws_s3_bucket.cake_agents[0].bucket
        region  = data.aws_region.current.region
        prefix  = var.s3_prefix
      }
    } : {},
    var.slack == null ? {} : {
      slack = {
        secret = {
          create = false
          name   = kubernetes_secret_v1.cake_agents_slack_creds[0].metadata[0].name
        }
      }
    },
    var.oidc == null ? {} : {
      oidc = {
        enabled      = true
        providerId   = var.oidc.provider_id
        domain       = var.oidc.domain
        issuer       = var.oidc.issuer
        clientId     = var.oidc.client_id
        publicClient = var.oidc.public_client
        clientSecret = {
          create = false
          name   = var.oidc.public_client ? null : kubernetes_secret_v1.cake_agents_oidc_creds[0].metadata[0].name
          key    = var.oidc.public_client ? null : "clientSecret"
        }
      }
    },
  ))]

  depends_on = [
    helm_release.karpenter,
    helm_release.aws_load_balancer_controller,
    kubernetes_secret_v1.cake_agents_db_creds,
    kubernetes_secret_v1.cake_agents_slack_creds,
    kubernetes_secret_v1.cake_agents_oidc_creds,
    aws_eks_pod_identity_association.cake_agents,
    null_resource.warmup_chart,
  ]
}

# Ingress for the cake-agents service. Routes hostname -> svc/cake-agents:80
# via an internet-facing ALB with the supplied ACM cert.
resource "kubernetes_ingress_v1" "cake_agents" {
  wait_for_load_balancer = true

  metadata {
    name      = "cake-agents"
    namespace = kubernetes_namespace_v1.cake_agents.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path"         = "/api/health"
      "alb.ingress.kubernetes.io/listen-ports"             = jsonencode([{ HTTPS = 443 }, { HTTP = 80 }])
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "routing.http.preserve_host_header.enabled=true"
      "alb.ingress.kubernetes.io/ssl-redirect"             = "443"
      "alb.ingress.kubernetes.io/certificate-arn"          = var.certificate_arn
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = var.hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "cake-agents"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.cake_agents,
  ]
}

# Look up the LBC-provisioned ALB by tags so we can wire its zone_id into
# the Route53 alias record.
data "aws_lb" "cake_agents" {
  tags = {
    "elbv2.k8s.aws/cluster" = module.eks.cluster_name
    "ingress.k8s.aws/stack" = "${kubernetes_namespace_v1.cake_agents.metadata[0].name}/${kubernetes_ingress_v1.cake_agents.metadata[0].name}"
  }

  depends_on = [kubernetes_ingress_v1.cake_agents]
}

resource "aws_route53_record" "cake_agents_apex" {
  zone_id = var.route53_zone_id
  name    = var.hostname
  type    = "A"

  alias {
    name                   = data.aws_lb.cake_agents.dns_name
    zone_id                = data.aws_lb.cake_agents.zone_id
    evaluate_target_health = true
  }
}
