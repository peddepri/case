variable "role_name" {
  description = "Name for the IAM role"
  type        = string
  default     = "GitHubActionsRole"
}

variable "repo_owner" {
  description = "GitHub repository owner/organization"
  type        = string
  default     = "peddepri"
}

variable "repo_name" {
  description = "GitHub repository name"
  type        = string
  default     = "case"
}

variable "aws_region" {
  description = "AWS region for resource scoping"
  type        = string
  default     = "us-east-2"
}

variable "managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach to the role"
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  ]
}

variable "allowed_subs" {
  description = "List of allowed token subject strings for GitHub Actions"
  type        = list(string)
  default = [
    "repo:peddepri/case:ref:refs/heads/*",
    "repo:peddepri/case:ref:refs/tags/*",
    "repo:peddepri/case:environment:*",
    "repo:peddepri/case:pull_request"
  ]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "case"
    Environment = "all"
    ManagedBy   = "Terraform"
  }
}