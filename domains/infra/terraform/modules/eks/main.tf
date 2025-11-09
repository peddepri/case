module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  cluster_addons = {
    coredns    = { most_recent = true }
    vpc-cni    = { most_recent = true }
    kube-proxy = { most_recent = true }
  }

  # Fargate Profiles
  fargate_profiles = {
    case = {
      name       = "case"
      subnet_ids = var.subnet_ids
      selectors = [
        {
          namespace = "case"
        }
      ]
    }
    kube_system = {
      name       = "kube-system" 
      subnet_ids = var.subnet_ids
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            "k8s-app" = "kube-dns"
          }
        }
      ]
    }
  }

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  tags = var.tags
}

# OIDC Provider para IRSA
resource "aws_iam_openid_connect_provider" "eks" {
  url             = module.eks.cluster_oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]

  tags = var.tags
}