variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "URL do OIDC issuer do cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}