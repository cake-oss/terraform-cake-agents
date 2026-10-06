# First-class istio support.
#
# When var.istio.enabled is true this file owns the whole ingress path:
#
#   client --TLS(ACM cert)--> ALB --TLS(self-signed cert)--> istio-ingressgateway
#     --mTLS(istio auto-mTLS between sidecars)--> cake-agents
#
# and cake_agents.tf stops creating the Ingress that points the ALB straight at
# the cake-agents Service. The ALB still terminates the public ACM certificate.
# The second hop is re-encrypted because istio cannot use an ACM public
# certificate (ACM never exports the private key), so cert-manager issues a
# self-signed credential for the Gateway; the ALB does not validate the
# gateway's certificate, so self-signed is sufficient.
#
# Everything here is gated on local.istio_enabled. With istio disabled the
# cluster gets no mesh, no cert-manager, and the original ALB -> Service
# Ingress.

locals {
  istio_enabled = var.istio != null && var.istio.enabled

  # Whether to label the release namespace istio-injection=enabled. See the
  # namespace resource in cake_agents.tf for why namespace-level injection is
  # needed on top of the chart's per-pod annotation.
  istio_inject_namespace = var.istio == null ? false : (var.istio.enabled && var.istio.inject)

  istio_namespace = "istio-system"

  # Load-bearing name: the gateway chart derives its pod labels from the release
  # name (app: istio-ingressgateway, istio: ingressgateway), and both the
  # Gateway selector below and the cake-agents chart's AuthorizationPolicy
  # selectors match exactly those labels.
  istio_gateway_name = "istio-ingressgateway"

  # Name of the Gateway resource this module renders (see below). The chart's
  # VirtualService is pointed at it as istio-system/<name>.
  istio_gateway_config_name = "cake-agents-gateway"

  istio_ingress_name = "cake-agents"

  # base/istiod/gateway are versioned and released together by the istio
  # project, so bump them in lockstep: the gateway's proxy image tag comes from
  # istiod's injected values, not from the gateway chart itself. 1.30 supports
  # Kubernetes 1.32-1.36, which covers this module's kubernetes_version.
  #
  # Images come from docker.io/istio. The ECR pull-through cache this module
  # provisions only mirrors the Cake registry, so nodes pull istio images
  # through the NAT gateway directly.
  istio_chart_repository = "https://istio-release.storage.googleapis.com/charts"
  istio_chart_version    = "1.30.5"

  cert_manager_namespace     = "cert-manager"
  cert_manager_chart_version = "v1.21.2"
  cert_manager_issuer_name   = "cake-agents-selfsigned"

  # Secret the cake-agents Gateway references as credentialName. It is issued
  # into istio-system, where istiod looks for gateway credentials (see the
  # Certificate below).
  istio_gateway_credential_name = var.istio != null ? var.istio.gateway.credential_name : "istio-gateway-certificate-tls"

  # The AWS Load Balancer Controller tags each ALB with the Ingress that owns it
  # as <namespace>/<name>. istio moves that Ingress to istio-system, because an
  # Ingress can only reference Services in its own namespace and the gateway
  # Service lives there.
  cake_agents_alb_stack = local.istio_enabled ? "${local.istio_namespace}/${local.istio_ingress_name}" : "${kubernetes_namespace_v1.cake_agents.metadata[0].name}/${local.istio_ingress_name}"
}

# Istio on the cluster: base (mesh CRDs) -> istiod (control plane) ->
# istio-ingressgateway (data-plane entrypoint).
#
# The order is load-bearing, not cosmetic:
#
#   - istiod's config and webhooks are CRD-backed, so base has to land first.
#   - the gateway chart renders `image: auto`, which istiod's sidecar injector
#     rewrites to the real gateway image when it admits the pod. A gateway
#     applied before istiod sits in ImagePullBackOff on the literal tag "auto".
#
# istio_base carries the depends_on edges for all three releases (the others
# inherit them through their own edges below): istiod and the gateway schedule
# onto Karpenter workload nodes and the ALB in front of the gateway is
# reconciled by the AWS Load Balancer Controller, so nothing here should be
# applied before Karpenter, the LBC, the cluster and the VPC exist. On destroy
# the same edges keep the VPC (subnets, NAT gateways) and the node pools alive
# until these releases are gone, so the LBC can still delete the ALB -- and
# clear its finalizer -- before the subnets holding its ENIs disappear.
#
# Careful on teardown: base renders the CRDs as ordinary templates (so istio can
# upgrade them with the chart), so destroying istio_base deletes them and
# Kubernetes cascade-deletes every istio CR in the cluster -- Gateways,
# VirtualServices, AuthorizationPolicies, and the rest of the mesh config. The
# cake-agents release (and its Gateway/VirtualService) is destroyed first, so
# this only ever deletes what is already gone.
resource "helm_release" "istio_base" {
  count = local.istio_enabled ? 1 : 0

  namespace        = local.istio_namespace
  create_namespace = true
  name             = "istio-base"
  repository       = local.istio_chart_repository
  chart            = "base"
  version          = local.istio_chart_version
  wait             = true
  timeout          = 900

  depends_on = [
    helm_release.karpenter,
    helm_release.aws_load_balancer_controller,
    module.eks,
    module.vpc,
  ]
}

resource "helm_release" "istiod" {
  count = local.istio_enabled ? 1 : 0

  namespace  = local.istio_namespace
  name       = "istiod"
  repository = local.istio_chart_repository
  chart      = "istiod"
  version    = local.istio_chart_version
  wait       = true
  timeout    = 900

  values = [yamlencode({
    sidecarInjectorWebhook = {
      # Injection is enabled per namespace rather than cluster-wide: the release
      # namespace carries istio-injection=enabled (see
      # kubernetes_namespace_v1.cake_agents), which enrols both the chart's own
      # pods and the session StatefulSets the control plane creates at runtime
      # -- those carry no sidecar.istio.io/inject annotation, so pod-level
      # opt-in alone would leave them outside the mesh.
      #
      # Deliberately not enableNamespacesByDefault: that would make istiod a
      # cluster-wide admission dependency (every injector entry is
      # failurePolicy: Fail), so an istiod outage would block pod CREATEs for
      # Karpenter, the AWS Load Balancer Controller and CoreDNS too.
      enableNamespacesByDefault = false
    }
  })]

  depends_on = [
    helm_release.istio_base,
    # istiod's injection and validation webhooks listen on 15017 and are called
    # by the EKS API server, whose ENIs sit in the cluster security group. The
    # node security group only opens the control-plane webhook ports the EKS
    # module knows about (4443/6443/8443/9443) plus kubelet 10250, so 15017 is
    # opened below. Without it sidecar injection silently fails and, because
    # every istio-sidecar-injector entry is failurePolicy: Fail, every pod CREATE
    # matching the webhook is rejected.
    aws_vpc_security_group_ingress_rule.istiod_webhook_from_cluster,
  ]
}

resource "helm_release" "istio_ingressgateway" {
  count = local.istio_enabled ? 1 : 0

  namespace  = local.istio_namespace
  name       = local.istio_gateway_name
  repository = local.istio_chart_repository
  chart      = "gateway"
  version    = local.istio_chart_version
  wait       = true
  timeout    = 900

  values = [yamlencode({
    service = {
      # The ALB below fronts the gateway, so the Service must not ask for a load
      # balancer of its own. ClusterIP keeps the pod endpoints that the AWS Load
      # Balancer Controller registers as ip-type targets without provisioning an
      # NLB (external type) or a Classic LB (in-tree controller) nobody uses.
      type = "ClusterIP"
    }
    serviceAccount = {
      create = true
      # The cake-agents chart's AuthorizationPolicies allow traffic to the
      # control plane from
      # cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account.
      # The gateway chart would otherwise name the ServiceAccount after the
      # release (istio-ingressgateway), which would leave every request through
      # the gateway denied by the chart's web-sidecar ALLOW policy.
      name = "istio-ingressgateway-service-account"
    }
  })]

  depends_on = [helm_release.istiod]
}

resource "aws_vpc_security_group_ingress_rule" "istiod_webhook_from_cluster" {
  count = local.istio_enabled ? 1 : 0

  security_group_id            = module.eks.node_security_group_id
  referenced_security_group_id = module.eks.cluster_security_group_id
  from_port                    = 15017
  to_port                      = 15017
  ip_protocol                  = "tcp"
  # No apostrophes: EC2 only accepts a-zA-Z0-9 and ._-:/()#,@[]+=&;{}!$* here.
  description = "Allow the EKS API server to reach istiod injection/validation webhooks"
}

# cert-manager exists for exactly one job here: issuing (and renewing) the
# self-signed credential the cake-agents Gateway terminates TLS with. Its
# webhook listens on 10250, which the EKS module already opens from the cluster
# security group for kubelet, so no extra rule is needed.
resource "helm_release" "cert_manager" {
  count = local.istio_enabled ? 1 : 0

  namespace        = local.cert_manager_namespace
  create_namespace = true
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = local.cert_manager_chart_version
  wait             = true
  timeout          = 900

  values = [yamlencode({
    crds = {
      enabled = true
      # Keep the CRDs on uninstall: deleting them makes Kubernetes
      # cascade-delete every Certificate/Issuer in the cluster mid-teardown.
      keep = true
    }
  })]

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "cert_manager_selfsigned_issuer" {
  count = local.istio_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = local.cert_manager_issuer_name }
    spec       = { selfSigned = {} }
  })

  depends_on = [helm_release.cert_manager]
}

# Gateway for the ALB -> ingressgateway hop.
#
# hosts has to be the full wildcard rather than the control-plane hostname:
# istio turns a TLS server's hosts into the listener's SNI match
# (filterChainMatch.serverNames), and the ALB does not send SNI to its targets,
# so a host-scoped server rejects every connection from the load balancer with
# filter_chain_not_found. A wildcard server generates no server_names match, so
# the handshake succeeds without SNI and the hostname is then matched on the
# HTTP Host header by the chart's VirtualService -- which the ALB preserves via
# routing.http.preserve_host_header.enabled on the Ingress below.
#
# That is also why the module renders this Gateway instead of letting the chart
# render its own (istio.gateway.create): the chart's is host-scoped. The chart's
# VirtualService is pointed here via istio.gateway.name.
resource "kubectl_manifest" "cake_agents_gateway" {
  count = local.istio_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "networking.istio.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = local.istio_gateway_config_name
      namespace = local.istio_namespace
    }
    spec = {
      selector = {
        app   = local.istio_gateway_name
        istio = "ingressgateway"
      }
      servers = [
        {
          port = {
            number   = 443
            name     = "https"
            protocol = "HTTPS"
          }
          tls = {
            mode           = "SIMPLE"
            credentialName = local.istio_gateway_credential_name
          }
          hosts = ["*"]
        },
      ]
    }
  })

  depends_on = [
    helm_release.istio_ingressgateway,
    kubectl_manifest.cake_agents_gateway_certificate,
  ]
}

# The credential the Gateway above references as credentialName. cert-manager
# renews it on its default 90-day schedule and istio picks the rotated secret up
# over SDS without a restart, so there is no expiry cliff to re-apply against.
#
# The secret has to land in istio-system, i.e. next to the gateway *proxy*:
# istiod only releases a Kubernetes secret over SDS when the requested namespace
# equals the requesting proxy's, after a SubjectAccessReview that the gateway
# ServiceAccount can list secrets there -- which the gateway chart's own
# Role/RoleBinding grants.
resource "kubectl_manifest" "cake_agents_gateway_certificate" {
  count = local.istio_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "cake-agents-gateway"
      namespace = local.istio_namespace
    }
    spec = {
      secretName = local.istio_gateway_credential_name
      issuerRef = {
        name = local.cert_manager_issuer_name
        kind = "ClusterIssuer"
      }
      dnsNames = [var.hostname]
      privateKey = {
        algorithm      = "RSA"
        size           = 2048
        rotationPolicy = "Always"
      }
      usages = [
        "server auth",
        "digital signature",
        "key encipherment",
      ]
    }
  })

  depends_on = [
    kubectl_manifest.cert_manager_selfsigned_issuer,
    # istio_base creates the istio-system namespace.
    helm_release.istio_base,
  ]
}

# ALB in front of the istio ingressgateway, replacing the cake-agents Ingress
# that cake_agents.tf creates when istio is disabled. It has to live in
# istio-system: an Ingress can only reference Services in its own namespace, and
# the gateway Service is there.
resource "kubernetes_ingress_v1" "cake_agents_istio" {
  count = local.istio_enabled ? 1 : 0

  wait_for_load_balancer = true

  metadata {
    name      = local.istio_ingress_name
    namespace = local.istio_namespace
    annotations = {
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/listen-ports"             = jsonencode([{ HTTPS = 443 }, { HTTP = 80 }])
      "alb.ingress.kubernetes.io/ssl-redirect"             = "443"
      "alb.ingress.kubernetes.io/certificate-arn"          = var.certificate_arn
      "alb.ingress.kubernetes.io/ssl-policy"               = "ELBSecurityPolicy-TLS13-1-2-FIPS-2023-04"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "routing.http.preserve_host_header.enabled=true"
      # Re-encrypt to the gateway: istio terminates TLS on 443 with the
      # self-signed credential issued above, so the ALB has to speak HTTPS to
      # its targets. preserve_host_header (above) keeps Host: <hostname> intact;
      # without it the ALB rewrites Host to the target and the chart's
      # VirtualService, which matches on the control-plane host, 404s.
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      # Health-check the gateway's own readiness endpoint instead of the TLS
      # listener: pilot-agent serves /healthz/ready over plain HTTP on the
      # status port, while a check that lands on 443 carries Host: <target IP>
      # and matches no VirtualService. The controller adds the security-group
      # rule for the health-check port alongside the traffic-port rule, so the
      # status port is reachable from the load balancer.
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/healthcheck-port"     = "status-port"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/healthz/ready"
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
              name = local.istio_gateway_name
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    # The Gateway/VirtualService have to exist before the ALB starts routing,
    # and the credential before istio can terminate TLS on 443.
    helm_release.cake_agents,
    helm_release.istio_ingressgateway,
    kubectl_manifest.cake_agents_gateway,
    kubectl_manifest.cake_agents_gateway_certificate,
    # Destroy the ingress (and let the LBC fully delete the ALB and target
    # group) before the NodePool is deleted, so the workload nodes backing the
    # ALB targets are still alive during target-group teardown.
    kubectl_manifest.karpenter_nodepool,
  ]
}
