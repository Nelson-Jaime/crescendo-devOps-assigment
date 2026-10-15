variable "name_prefix" {
  description = "Prefix used in the distribution comment."
  type        = string
}

variable "origin_domain_name" {
  description = "DNS name of the ALB origin."
  type        = string
}

variable "origin_verify_secret" {
  description = "Secret sent to the origin in the X-Origin-Verify header."
  type        = string
  sensitive   = true
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "static_path_patterns" {
  description = "Path patterns served with the long-lived caching policy."
  type        = list(string)
  default     = ["/.resources/*", "/dam/*", "/docroot/*"]
}

variable "wait_for_deployment" {
  description = "Wait for the distribution to finish deploying."
  type        = bool
  default     = true
}
