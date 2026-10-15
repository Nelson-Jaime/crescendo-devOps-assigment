output "dns_name" {
  description = "DNS name of the ALB (CloudFront origin)."
  value       = aws_lb.this.dns_name
}

output "security_group_id" {
  description = "Security group of the ALB; the instance allows traffic from it."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the application target group."
  value       = aws_lb_target_group.app.arn
}
