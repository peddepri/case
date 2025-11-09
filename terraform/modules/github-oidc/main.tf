terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# OIDC Identity Provider for GitHub Actions (usar existente)
data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::918859180133:oidc-provider/token.actions.githubusercontent.com"
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = var.role_name
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = var.allowed_subs
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "GitHub Actions Role - ${var.repo_name}"
  })
}

# Anexar managed policies (Terraform faz em paralelo automaticamente)
resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}

# Inline policy customizada (minimalista e segura)
resource "aws_iam_role_policy" "custom" {
  name = "${var.role_name}-CustomPolicy"
  role = aws_iam_role.github_actions.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EKS Cluster Management (scoped)
      {
        Sid    = "EKSClusterAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeUpdate",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:TagResource",
          "eks:UntagResource"
        ]
        Resource = [
          "arn:aws:eks:${var.aws_region}:${local.account_id}:cluster/${var.repo_name}-*",
          "arn:aws:eks:${var.aws_region}:${local.account_id}:nodegroup/${var.repo_name}-*/*/*"
        ]
      },
      # EC2 Read-Only for EKS
      {
        Sid    = "EC2ReadOnlyAccess"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      # ECR Authentication (global)
      {
        Sid      = "ECRAuthAccess"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      # ECR Repository Operations (scoped)
      {
        Sid    = "ECRRepositoryAccess"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = [
          "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${var.repo_name}-backend",
          "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${var.repo_name}-frontend",
          "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${var.repo_name}-mobile"
        ]
      },
      # CloudWatch Logs
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/eks/${var.repo_name}-*",
          "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/containerinsights/${var.repo_name}-*"
        ]
      },
      # IAM PassRole (restricted with condition)
      {
        Sid    = "IAMPassRoleRestricted"
        Effect = "Allow"
        Action = ["iam:GetRole", "iam:PassRole"]
        Resource = [
          "arn:aws:iam::${local.account_id}:role/${var.repo_name}-*",
          "arn:aws:iam::${local.account_id}:role/*EKS*",
          "arn:aws:iam::${local.account_id}:role/*eks*"
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = ["eks.amazonaws.com", "ec2.amazonaws.com"]
          }
        }
      },
      # S3 for Terraform State (if using)
      {
        Sid    = "S3TerraformStateAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::terraform-state-${var.repo_name}-*",
          "arn:aws:s3:::terraform-state-${var.repo_name}-*/*"
        ]
      },
      # DynamoDB for Terraform Locks (if using)
      {
        Sid      = "DynamoDBTerraformLockAccess"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = ["arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/terraform-state-lock-${var.repo_name}-*"]
      },
      # KMS (scoped to EKS/ECR services)
      {
        Sid      = "KMSAccess"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = ["arn:aws:kms:${var.aws_region}:${local.account_id}:key/*"]
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "eks.${var.aws_region}.amazonaws.com",
              "ecr.${var.aws_region}.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

# Data source para obter account ID
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}