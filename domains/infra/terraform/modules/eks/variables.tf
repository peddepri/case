variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "cluster_version" {
  description = "Versão do Kubernetes"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "ID da VPC onde o cluster será criado"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets para o cluster"
  type        = list(string)
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Habilitar permissões de admin para quem criou o cluster"
  type        = bool
  default     = true
}