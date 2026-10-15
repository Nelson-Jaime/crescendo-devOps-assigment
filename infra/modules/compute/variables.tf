variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC of the instance."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet that hosts the instance."
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group of the ALB; the only source allowed to reach the instance."
  type        = string
}

variable "ami_id" {
  description = "AMI ID. Null resolves the latest Amazon Linux 2023 x86_64 AMI."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size_gb" {
  description = "Size of the encrypted gp3 root volume."
  type        = number
  default     = 30
}

variable "tomcat_version" {
  description = "Apache Tomcat 9.0.x version."
  type        = string
}

variable "java_package" {
  description = "dnf package providing the JRE."
  type        = string
}

variable "magnolia_war_url" {
  description = "Magnolia CE WAR download URL (a .sha1 must exist next to it)."
  type        = string
}

variable "jvm_heap_mb" {
  description = "JVM heap (-Xms/-Xmx) in MiB."
  type        = number
}

variable "magnolia_instance_type" {
  description = "\"public\" or \"author\"."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "author"], var.magnolia_instance_type)
    error_message = "magnolia_instance_type must be \"public\" or \"author\"."
  }
}

variable "expose_admin" {
  description = "Expose /.magnolia through Nginx."
  type        = bool
  default     = false
}
