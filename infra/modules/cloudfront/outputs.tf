output "domain_name" {
  description = "The *.cloudfront.net domain of the distribution."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_id" {
  description = "ID of the distribution."
  value       = aws_cloudfront_distribution.this.id
}
