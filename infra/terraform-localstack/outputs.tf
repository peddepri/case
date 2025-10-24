output "ecr_backend_repo_url" {
  description = "Backend ECR repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repo_url" {
  description = "Frontend ECR repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.orders.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.orders.arn
}

output "backend_irsa_role_arn" {
  description = "Backend ServiceAccount IAM role ARN"
  value       = aws_iam_role.backend_sa.arn
}

output "backend_irsa_role_name" {
  description = "Backend ServiceAccount IAM role name"
  value       = aws_iam_role.backend_sa.name
}

output "datadog_secret_arn" {
  description = "Datadog API key secret ARN"
  value       = aws_secretsmanager_secret.datadog_api_key.arn
}

output "artifacts_bucket" {
  description = "S3 bucket for artifacts"
  value       = aws_s3_bucket.artifacts.id
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.app_logs.name
}
