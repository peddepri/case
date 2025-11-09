# Outputs do módulo
output "role_arn" {
  description = "ARN of the GitHub Actions IAM Role"
  value       = module.github_oidc.role_arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC Provider"  
  value       = module.github_oidc.oidc_provider_arn
}

output "role_name" {
  description = "Name of the GitHub Actions IAM Role"
  value       = module.github_oidc.role_name
}

output "setup_instructions" {
  description = "Instructions to configure GitHub secret"
  value       = module.github_oidc.setup_instructions
}