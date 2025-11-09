variable "role_name" {
  description = "Nome da IAM role"
  type        = string
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN do OIDC provider"
  type        = string
}

variable "namespace" {
  description = "Namespace do Kubernetes"
  type        = string
}

variable "service_account_name" {
  description = "Nome da service account"
  type        = string
}

variable "policy_arns" {
  description = "Lista de ARNs de policies para anexar à role"
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Policies inline para a role"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}