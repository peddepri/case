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

  # Fargate Profiles (right-sized by workload type to enable granular policies/cost tracking)
  fargate_profiles = {
    backend = {
      name       = "backend"
      subnet_ids = var.subnet_ids
      selectors = [
        {
          namespace = "case"
          labels = {
            app = "backend"
          }
        }
      ]
    }
    frontend = {
      name       = "frontend"
      subnet_ids = var.subnet_ids
      selectors = [
        {
          namespace = "case"
          labels = {
            app = "frontend"
          }
        }
      ]
    }
    mobile = {
      name       = "mobile"
      subnet_ids = var.subnet_ids
      selectors = [
        {
          namespace = "case"
          labels = {
            app = "mobile"
          }
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

  # Habilita acesso público ao endpoint do EKS para permitir que o Terraform (fora da VPC) aplique recursos Kubernetes/Helm
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Desabilita criação de OIDC provider pelo módulo para evitar conflito (já existe no ambiente AWS)
  enable_irsa = false

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  tags = var.tags
}

// Reintroduz OIDC Provider gerenciado por este módulo wrapper, evitando conflito com criação interna do módulo EKS.
resource "aws_iam_openid_connect_provider" "eks" {
  url             = module.eks.cluster_oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]

  tags = var.tags
}