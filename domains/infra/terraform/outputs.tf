output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_id
}

output "eks_cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

output "ecr_backend_repo_url" {
  description = "URL of the ECR repository for backend"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repo_url" {
  description = "URL of the ECR repository for frontend" 
  value       = aws_ecr_repository.frontend.repository_url
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.orders.name
}

output "backend_irsa_role_arn" {
  description = "ARN of the backend IRSA role"
  value       = module.backend_irsa.role_arn
}

output "alb_controller_role_arn" {
  description = "ARN of the ALB Controller IRSA role"
  value       = module.alb_controller.alb_controller_role_arn
}
