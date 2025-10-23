output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_backend_repo_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repo_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.orders.name
}

output "backend_irsa_role_arn" {
  value = aws_iam_role.backend_irsa.arn
}
