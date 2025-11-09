variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "profile_name" {
  description = "Nome do Fargate profile"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets para o Fargate profile"
  type        = list(string)
}

variable "selectors" {
  description = "Seletores para o Fargate profile"
  type = list(object({
    namespace = string
    labels    = optional(map(string), {})
  }))
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}