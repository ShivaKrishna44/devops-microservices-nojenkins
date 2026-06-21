## eks-addons ###

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = module.eks.cluster_name

  addon_name = "aws-ebs-csi-driver"

  service_account_role_arn = aws_iam_role.ebs_csi.arn

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi
  ]
}