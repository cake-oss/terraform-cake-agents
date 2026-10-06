# EKS access policy associations complete at the AWS API level before the
# Kubernetes API server reflects them. A short sleep lets auth propagate so
# subsequent kubectl calls don't get "forbidden" errors.
resource "time_sleep" "eks_auth_propagation" {
  create_duration = "15s"

  triggers = {
    access_entries = jsonencode(module.eks.access_entries)
  }
}

resource "kubernetes_namespace_v1" "cake_agents" {
  metadata {
    name = "cake-agents"

    # Injection has to be namespace-scoped, not just the chart's per-pod
    # sidecar.istio.io/inject annotation: the control plane creates session
    # StatefulSets in this namespace at runtime and they carry no istio
    # annotation, so they would never be injected. That breaks the mesh in two
    # ways. The chart's AuthorizationPolicies match source.namespaces and
    # source.principals, which istio derives from the peer certificate, so they
    # only match meshed callers -- a sidecar-less session pod is denied by the
    # web-sidecar ALLOW policy. And istio.outboundAllowlist (a Sidecar in
    # REGISTRY_ONLY mode plus ServiceEntries selecting data-plane pods) is inert
    # without sidecars to apply it to.
    #
    # Scoped to this namespace on purpose: istiod's enableNamespacesByDefault
    # stays off, so istiod is an admission dependency for cake-agents only, not
    # for Karpenter, the AWS Load Balancer Controller or CoreDNS.
    labels = local.istio_inject_namespace ? { "istio-injection" = "enabled" } : null
  }

  # Order this namespace's destroy ahead of two things that its finalizer
  # depends on. Deleting the namespace runs a discovery sweep that proxies
  # through the API server to the metrics-server pod (which registers the
  # v1beta1.metrics.k8s.io aggregated APIService); if that path is broken while
  # the namespace is still Terminating, the sweep fails with
  # NamespaceDeletionDiscoveryFailure and the namespace hangs.
  #
  #   module.eks - keeps the metrics-server addon and its host nodes alive.
  #   module.vpc - keeps the in-cluster data path (private route table + NAT)
  #                alive. The proxied metrics-server call is control-plane ENI
  #                -> pod/kubelet in the private subnets; module.eks/subnet refs
  #                pin the subnets but NOT the routes/NAT, so without this edge
  #                Terraform tears them down in parallel with the namespace and
  #                metrics.k8s.io goes unavailable mid-finalize.
  #
  # Both are resource-level depends_on (this is a resource, not a module block),
  # so they don't trigger the count-unknown problem that a module-level
  # depends_on = [module.vpc] would.
  depends_on = [
    time_sleep.eks_auth_propagation,
    module.eks,
    module.vpc,
  ]
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

# Renders var.istio into the chart's istio block. Most attributes keep the
# chart's own defaults (mirrored by the variable type), so a partial override
# still produces a complete block. When var.istio is null nothing is passed at
# all and the chart defaults stand.
#
# Three attributes resolve against what this module installs instead, because
# the chart defaults describe a shared upstream mesh rather than the one
# istio.tf builds:
#
#   gateway.name/create        there is no shared Kubeflow gateway here, and the
#                              chart's own Gateway is host-scoped -- unusable
#                              behind an ALB, which sends no SNI. istio.tf
#                              renders a wildcard-host Gateway instead, so the
#                              chart must not create one and its VirtualService
#                              is pointed at istio-system/cake-agents-gateway.
#   authorizationPolicy.create the chart's ingress policies reference an
#                              oauth2-proxy extension provider that this
#                              module's istiod does not configure, and istiod
#                              turns an unresolvable CUSTOM action into deny
#                              rules for the matched paths -- which would 403
#                              the entire app. Off unless explicitly asked for.
locals {
  cake_agents_istio_values = var.istio == null ? {} : {
    istio = {
      enabled = var.istio.enabled
      inject  = var.istio.inject
      gateway = {
        name           = var.istio.gateway.name != null ? var.istio.gateway.name : (local.istio_enabled ? "${local.istio_namespace}/${local.istio_gateway_config_name}" : "kubeflow/kubeflow-gateway")
        create         = var.istio.gateway.create != null ? var.istio.gateway.create : !local.istio_enabled
        credentialName = local.istio_gateway_credential_name
      }
      authorizationPolicy = {
        create = var.istio.authorization_policy.create != null ? var.istio.authorization_policy.create : !local.istio_enabled
      }
      outboundAllowlist = [
        for entry in var.istio.outbound_allowlist : merge(
          {
            name  = entry.name
            hosts = entry.hosts
          },
          entry.ports == null ? {} : {
            ports = [
              for port in entry.ports : merge(
                {
                  number   = port.number
                  protocol = port.protocol
                },
                port.name == null ? {} : { name = port.name },
              )
            ]
          },
        )
      ]
    }
  }
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
        default = local.image_registry
      }
      image = {
        tag = coalesce(var.cake_agents_image_tag, var.cake_agents_chart_version)
      }
      controlPlane = {
        host = var.hostname
        extraHosts = concat(
          var.oidc == null ? [] : [regex("^https?://([^/:]+)", var.oidc.issuer)[0]],
          var.extra_hosts,
        )
        deployment = {
          extraEnv = concat(
            [
              {
                name  = "CAKE_CONSOLE_URL"
                value = var.cake_console_url
              }
            ],
            var.password_auth_enabled ? [
              {
                name  = "CAKE_EMAIL_AND_PASSWORD_ENABLED"
                value = "true"
              }
            ] : [],
          )
        }
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
      oidc = merge(
        {
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
        },
        var.oidc.scopes == null ? {} : { scopes = var.oidc.scopes },
      )
    },
    local.cake_agents_istio_values,
  ))]

  depends_on = [
    helm_release.karpenter,
    helm_release.aws_load_balancer_controller,
    kubernetes_secret_v1.cake_agents_db_creds,
    kubernetes_secret_v1.cake_agents_slack_creds,
    kubernetes_secret_v1.cake_agents_oidc_creds,
    aws_eks_pod_identity_association.cake_agents,
    # With istio enabled the chart renders a Gateway and a VirtualService, so
    # the mesh CRDs (istio-base), istiod and the gateway have to exist first --
    # an apply against a cluster without the CRDs fails with "no matches for
    # kind Gateway". The credential is issued first so istio can terminate TLS
    # as soon as the Gateway lands; istio picks it up over SDS either way.
    helm_release.istio_base,
    helm_release.istiod,
    helm_release.istio_ingressgateway,
    kubectl_manifest.cake_agents_gateway,
    kubectl_manifest.cake_agents_gateway_certificate,
    # Tear the app down before the Karpenter NodePool. Deleting the NodePool
    # makes Karpenter drain the workload nodes; if that happens while the app is
    # still up, the in-flight ALB/target-group teardown loses its targets mid
    # delete and stalls. Ordering here keeps the workload nodes alive until the
    # app (and, transitively, the ingress that depends on it) is gone.
    kubectl_manifest.karpenter_nodepool,
  ]
}

# Ingress for the cake-agents service. Routes hostname -> svc/cake-agents:80
# via an internet-facing ALB with the supplied ACM cert and a FIPS TLS 1.2+
# SSL policy.
#
# Skipped when istio is enabled: istio.tf then fronts the istio ingressgateway
# with the ALB instead, and the chart's VirtualService routes to the service.
# Flipping istio.enabled therefore replaces the load balancer -- the ALB, its
# target groups and the Route53 alias target are all recreated.
resource "kubernetes_ingress_v1" "cake_agents" {
  count = local.istio_enabled ? 0 : 1

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
      "alb.ingress.kubernetes.io/ssl-policy"               = "ELBSecurityPolicy-TLS13-1-2-FIPS-2023-04"
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
    # Destroy the ingress (and let the LBC fully delete the ALB and target
    # group) before the NodePool is deleted, so the workload nodes backing the
    # ALB targets are still alive during target-group teardown.
    kubectl_manifest.karpenter_nodepool,
  ]
}

# Look up the LBC-provisioned ALB by tags so we can wire its zone_id into
# the Route53 alias record. The stack tag names the Ingress that owns the ALB,
# which is the istio-system one when the mesh is enabled.
data "aws_lb" "cake_agents" {
  tags = {
    "elbv2.k8s.aws/cluster" = module.eks.cluster_name
    "ingress.k8s.aws/stack" = local.cake_agents_alb_stack
  }

  depends_on = [
    kubernetes_ingress_v1.cake_agents,
    kubernetes_ingress_v1.cake_agents_istio,
  ]
}

resource "aws_route53_record" "cake_agents_apex" {
  count = var.route53_zone_id == null ? 0 : 1

  zone_id = var.route53_zone_id
  name    = var.hostname
  type    = "A"

  alias {
    name                   = data.aws_lb.cake_agents.dns_name
    zone_id                = data.aws_lb.cake_agents.zone_id
    evaluate_target_health = true
  }
}
