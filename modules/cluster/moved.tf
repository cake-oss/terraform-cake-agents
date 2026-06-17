moved {
  from = aws_iam_role.cake_agents_s3
  to   = aws_iam_role.cake_agents
}

moved {
  from = aws_eks_pod_identity_association.cake_agents_s3
  to   = aws_eks_pod_identity_association.cake_agents
}
