output "fargate_profile_arn" {
  description = "ARN do Fargate profile"
  value       = module.fargate_profile.fargate_profile_arn
}

output "fargate_profile_status" {
  description = "Status do Fargate profile"
  value       = module.fargate_profile.fargate_profile_status
}