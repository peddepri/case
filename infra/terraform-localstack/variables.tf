variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "case"
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "case-eks"
}

variable "dd_api_key" {
  description = "Datadog API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "dd_site" {
  description = "Datadog site"
  type        = string
  default     = "us5.datadoghq.com"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for orders"
  type        = string
  default     = "orders"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "localstack"
    Project     = "case"
    ManagedBy   = "terraform"
  }
}
