output "alb_controller_role_arn" {
  description = "ARN da role do AWS Load Balancer Controller"
  value       = module.alb_controller_irsa.role_arn
}