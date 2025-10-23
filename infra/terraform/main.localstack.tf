# Terraform configuration for LocalStack
# This is a simplified version that works with LocalStack's emulated AWS services

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.66"
    }
  }
  
  backend "s3" {
    bucket         = "case-terraform-state"
    key            = "localstack/terraform.tfstate"
    region         = "us-east-1"
    
    endpoint                    = "http://localstack:4566"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
    
    # LocalStack fake credentials
    access_key = "test"
    secret_key = "test"
  }
}

provider "aws" {
  region     = var.region
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    apigateway     = "http://localstack:4566"
    cloudformation = "http://localstack:4566"
    cloudwatch     = "http://localstack:4566"
    dynamodb       = "http://localstack:4566"
    ec2            = "http://localstack:4566"
    ecr            = "http://localstack:4566"
    eks            = "http://localstack:4566"
    iam            = "http://localstack:4566"
    lambda         = "http://localstack:4566"
    logs           = "http://localstack:4566"
    s3             = "http://localstack:4566"
    secretsmanager = "http://localstack:4566"
    sts            = "http://localstack:4566"
  }
}

locals {
  name = var.project_name
  tags = var.tags
}

# ECR Repositories
resource "aws_ecr_repository" "backend" {
  name                 = "backend"
  image_tag_mutability = "MUTABLE"
  tags                 = local.tags
}

resource "aws_ecr_repository" "frontend" {
  name                 = "frontend"
  image_tag_mutability = "MUTABLE"
  tags                 = local.tags
}

# DynamoDB for orders persistence
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

# IAM role for backend (IRSA simulation)
resource "aws_iam_role" "backend_sa" {
  name = "${local.name}-backend-sa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "backend_dynamodb" {
  role = aws_iam_role.backend_sa.id
  name = "${local.name}-backend-dynamodb"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DynamoDBAccess"
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan",
        "dynamodb:Query"
      ]
      Resource = aws_dynamodb_table.orders.arn
    }]
  })
}

# Secrets Manager for Datadog
resource "aws_secretsmanager_secret" "datadog_api_key" {
  name = "datadog/api-key"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "datadog_api_key" {
  secret_id = aws_secretsmanager_secret.datadog_api_key.id
  secret_string = jsonencode({
    api-key = var.dd_api_key != "" ? var.dd_api_key : "dummy-key-for-localstack"
  })
}

# S3 bucket for logs/artifacts (optional)
resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.name}-artifacts"
  tags   = local.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/containerinsights/${var.eks_cluster_name}/application"
  retention_in_days = 7
  tags              = local.tags
}
