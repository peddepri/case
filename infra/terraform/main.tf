locals {
  name = var.project_name
  tags = var.tags
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = local.name
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

# EKS
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.eks_cluster_name
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  cluster_addons = {
    coredns   = { most_recent = true }
    vpc-cni   = { most_recent = true }
    kube-proxy = { most_recent = true }
  }

  # Run workloads on EKS Fargate
  fargate_profiles = {
    case = {
      name       = "case"
      subnet_ids = module.vpc.private_subnets
      selectors = [
        {
          namespace = "case"
        }
      ]
    }
    kube_system = {
      name       = "kube-system"
      subnet_ids = module.vpc.private_subnets
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

  enable_cluster_creator_admin_permissions = true

  tags = local.tags
}

# OIDC Provider (for IRSA)
resource "aws_iam_openid_connect_provider" "eks" {
  url             = module.eks.cluster_oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [module.eks.oidc_provider_thumbprint]
}

# ECR Repositories
resource "aws_ecr_repository" "backend" {
  name                 = "backend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}

resource "aws_ecr_repository" "frontend" {
  name                 = "frontend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}

# Datadog Helm Chart
resource "helm_release" "datadog" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = "datadog"
  create_namespace = true

  values = [yamlencode({
    datadog = {
      site  = var.dd_site
      apm = { enabled = true }
      logs = { enabled = true }
      processAgent = { enabled = false }
      dogstatsd = { nonLocalTraffic = true }
      kubeStateMetricsEnabled = true
      kubelet = { tlsVerify = false }
      eksFargate = true
      containerExclude = ["name:datadog"]
      env = [
        { name = "DD_ENV", value = "prod" },
        { name = "DD_SERVICE", value = "cluster" },
        { name = "DD_VERSION", value = "0.1.0" }
      ]
    }
    agents = { enabled = false }
    clusterAgent = { enabled = true }
    apiKey = var.dd_api_key
  })]

  depends_on = [module.eks]
}

# DynamoDB for orders persistence (serverless, cost-efficient)
resource "aws_dynamodb_table" "orders" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.tags
}

# IRSA role for backend ServiceAccount to access DynamoDB
data "aws_iam_policy_document" "backend_irsa_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:case:backend-sa"]
    }

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
  }
}

resource "aws_iam_role" "backend_irsa" {
  name               = "${local.name}-backend-irsa"
  assume_role_policy = data.aws_iam_policy_document.backend_irsa_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "backend_dynamodb" {
  statement {
    sid     = "DynamoDBAccess"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
      "dynamodb:Query"
    ]
    resources = [aws_dynamodb_table.orders.arn]
  }
}

resource "aws_iam_role_policy" "backend_irsa_policy" {
  role   = aws_iam_role.backend_irsa.id
  name   = "${local.name}-backend-dynamodb"
  policy = data.aws_iam_policy_document.backend_dynamodb.json
}
