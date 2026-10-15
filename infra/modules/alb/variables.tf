variable "name_prefix" {
  description = "Prefix for resource names (max 20 characters: ALB and target group names are limited to 32)."
  type        = string

  validation {
    condition     = length(var.name_prefix) <= 20
    error_message = "name_prefix must be at most 20 characters."
  }
}

variable "vpc_id" {
  description = "VPC of the load balancer."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR; the ALB may send traffic to targets inside it."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets (two different AZs) for the ALB."
  type        = list(string)
}

variable "origin_verify_secret" {
  description = "Value of the X-Origin-Verify header that CloudFront must send."
  type        = string
  sensitive   = true
}

variable "cloudfront_prefix_list_id" {
  description = "CloudFront origin-facing managed prefix list. Null looks it up by name."
  type        = string
  default     = null
}

variable "target_instance_id" {
  description = "EC2 instance registered in the target group."
  type        = string
}

variable "target_port" {
  description = "Port the targets listen on."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "HTTP path used for target health checks. Magnolia REST status answers 200 on author and public instances; \"/\" would return 401 on an author instance."
  type        = string
  default     = "/.rest/status"
}
