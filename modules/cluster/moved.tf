moved {
  from = aws_iam_role.cake_agents_s3
  to   = aws_iam_role.cake_agents
}

moved {
  from = aws_eks_pod_identity_association.cake_agents_s3
  to   = aws_eks_pod_identity_association.cake_agents
}

# The cake-agents Ingress became count-addressed when istio support landed: it is
# skipped (count = 0) in favour of the istio-system Ingress in istio.tf when
# istio.enabled is true. Clusters that already deployed it keep the ALB, its
# target groups and the Route53 alias target instead of replacing them.
moved {
  from = kubernetes_ingress_v1.cake_agents
  to   = kubernetes_ingress_v1.cake_agents[0]
}
