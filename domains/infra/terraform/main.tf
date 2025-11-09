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

# EKS Cluster
module "eks" {
  source = "./modules/eks"

  cluster_name    = var.eks_cluster_name
  cluster_version = "1.30"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  tags = local.tags
}

# Fargate Profiles - incluídos no módulo EKS

# AWS Load Balancer Controller
module "alb_controller" {
  source = "./modules/alb"

  cluster_name             = var.eks_cluster_name
  cluster_oidc_issuer_url = module.eks.oidc_provider_arn
  vpc_id                  = module.vpc.vpc_id

  tags = local.tags
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

# IRSA role para backend acessar DynamoDB
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

module "backend_irsa" {
  source = "./modules/irsa"

  role_name           = "${local.name}-backend-irsa"
  cluster_name        = var.eks_cluster_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  namespace           = "case"
  service_account_name = "backend-sa"

  inline_policies = {
    DynamoDBAccess = data.aws_iam_policy_document.backend_dynamodb.json
  }

  tags = local.tags
}
