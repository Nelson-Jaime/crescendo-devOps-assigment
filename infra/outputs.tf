output "cloudfront_url" {
  description = "Public URL of the site (HTTPS, default CloudFront certificate)."
  value       = "https://${module.cloudfront.domain_name}"
}

output "alb_dns_name" {
  description = "DNS name of the ALB. Direct requests without the origin secret header return 403."
  value       = module.alb.dns_name
}

output "instance_id" {
  description = "ID of the Magnolia EC2 instance."
  value       = module.compute.instance_id
}

output "ssm_session_command" {
  description = "Open a shell on the instance (no SSH needed)."
  value       = "aws ssm start-session --target ${module.compute.instance_id} --region ${var.aws_region}"
}

output "ssm_port_forward_command" {
  description = "Reach the Magnolia admin UI on http://localhost:8080/.magnolia without exposing it publicly."
  value       = "aws ssm start-session --target ${module.compute.instance_id} --region ${var.aws_region} --document-name AWS-StartPortForwardingSession --parameters 'portNumber=80,localPortNumber=8080'"
}

output "nat_public_ips" {
  description = "Egress IPs of the private subnets."
  value       = module.network.nat_public_ips
}
