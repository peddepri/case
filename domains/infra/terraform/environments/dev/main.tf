# Development Environment Configuration

terraform {
  required_version = ">= 1.8.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.95"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }

  # backend "s3" {
  #   bucket = "case-terraform-state-dev"
  #   key    = "dev/terraform.tfstate"
  #   region = "us-east-2"
  #   
  #   dynamodb_table = "case-terraform-locks"
  #   encrypt        = true
  # }
}

# AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.tags
  }
}

# Kubernetes Provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Helm Provider
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# Local values
locals {
  environment = "dev"
  project     = "case"
  
  tags = {
    Environment = local.environment
    Project     = local.project
    ManagedBy   = "terraform"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.project}-vpc-${local.environment}"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = true  # Cost optimization for dev

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  cluster_name    = "${local.project}-${local.environment}"
  cluster_version = "1.28"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  tags = local.tags
}

# ECR Repositories
resource "aws_ecr_repository" "backend" {
  name                 = "${local.project}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${local.project}-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

resource "aws_ecr_repository" "mobile" {
  name                 = "${local.project}-mobile"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

# DynamoDB Table
resource "aws_dynamodb_table" "orders" {
  name           = "${local.project}-orders-${local.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.tags
}

# IRSA for Backend Service
module "backend_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.project}-backend-irsa-${local.environment}"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["case:backend-sa"]
    }
  }

  role_policy_arns = {
    dynamodb = aws_iam_policy.backend_dynamodb.arn
  }

  tags = local.tags
}

# Backend DynamoDB Policy
resource "aws_iam_policy" "backend_dynamodb" {
  name_prefix = "${local.project}-backend-dynamodb-${local.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.orders.arn
      }
    ]
  })

  tags = local.tags
}

# Observability Module
module "observability" {
  source = "../../modules/observability"

  cluster_name         = module.eks.cluster_name
  enable_datadog       = var.enable_datadog
  datadog_api_key      = var.datadog_api_key
  datadog_site         = var.datadog_site
  enable_grafana_stack = var.enable_grafana_stack

  tags = local.tags

  depends_on = [module.eks]
}