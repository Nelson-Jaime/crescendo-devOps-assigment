output "instance_id" {
  description = "ID of the Magnolia instance."
  value       = aws_instance.app.id
}

output "security_group_id" {
  description = "Security group of the instance."
  value       = aws_security_group.instance.id
}

output "private_ip" {
  description = "Private IP of the instance."
  value       = aws_instance.app.private_ip
}
