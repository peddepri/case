output "role_arn" {
  description = "ARN of the GitHub Actions IAM Role"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC Provider"
  value       = data.aws_iam_openid_connect_provider.github.arn
}

output "role_name" {
  description = "Name of the GitHub Actions IAM Role"
  value       = aws_iam_role.github_actions.name
}

output "setup_instructions" {
  description = "Instructions to configure GitHub secret"
  value = <<-EOT
    Configure este secret no GitHub:
    AWS_ROLE_TO_ASSUME: ${aws_iam_role.github_actions.arn}
    
    GitHub Secrets URL: https://github.com/${var.repo_owner}/${var.repo_name}/settings/secrets/actions
  EOT
}