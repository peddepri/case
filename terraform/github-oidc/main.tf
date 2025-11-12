terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Módulo GitHub OIDC
module "github_oidc" {
  source = "../modules/github-oidc"

  role_name   = "GitHubActionsRole"
  repo_owner  = "peddepri"
  repo_name   = "case"
  aws_region  = var.aws_region
  
  # Políticas AWS gerenciadas (lista mínima para reduzir blast radius)
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  ]

  # Permitir acesso de todos os branches/environments/PRs
  allowed_subs = [
    "repo:peddepri/case:ref:refs/heads/*",
    "repo:peddepri/case:ref:refs/tags/*", 
    "repo:peddepri/case:environment:*",
    "repo:peddepri/case:pull_request"
  ]

  tags = {
    Project     = "case"
    Environment = "all"
    ManagedBy   = "Terraform"
    Purpose     = "GitHub Actions OIDC"
  }
}