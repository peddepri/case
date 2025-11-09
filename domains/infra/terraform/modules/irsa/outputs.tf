output "role_arn" {
  description = "ARN da IAM role"
  value       = aws_iam_role.irsa.arn
}

output "role_name" {
  description = "Nome da IAM role"
  value       = aws_iam_role.irsa.name
}