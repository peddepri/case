variable "region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "project_name" {
  description = "Base name for resources"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "tags" {
  description = "Common tags applied to resources"
  type        = map(string)
  default     = {}
}

variable "dd_site" {
  description = "Datadog site (e.g., datadoghq.com, datadoghq.eu)"
  type        = string
  default     = "datadoghq.com"
}

variable "dd_api_key" {
  description = "Datadog API key (used for Cluster Agent and agentless APM)"
  type        = string
  sensitive   = true
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for orders"
  type        = string
  default     = "orders"
}
