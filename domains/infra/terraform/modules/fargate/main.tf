module "fargate_profile" {
  source = "terraform-aws-modules/eks/aws//modules/fargate-profile"

  name         = var.profile_name
  cluster_name = var.cluster_name
  subnet_ids   = var.subnet_ids

  selectors = var.selectors

  tags = var.tags
}