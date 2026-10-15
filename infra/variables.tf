variable "project" {
  description = "Project name, used as a prefix for resource names."
  type        = string
  default     = "crescendo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,14}$", var.project))
    error_message = "project must be 2-15 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name (dev, stage, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,9}$", var.environment))
    error_message = "environment must be 2-10 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "aws_region" {
  description = "AWS region for all regional resources. CloudFront is global."
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC. Must be a /16 so the /24 subnets can be derived."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && endswith(var.vpc_cidr, "/16")
    error_message = "vpc_cidr must be a valid IPv4 CIDR with a /16 prefix."
  }
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cheaper, single-AZ failure point) instead of one per AZ."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type. Magnolia needs memory: 4 GiB is the practical minimum."
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI to use. Null resolves the latest Amazon Linux 2023 x86_64 AMI."
  type        = string
  default     = null
}

variable "root_volume_size_gb" {
  description = "Size of the encrypted gp3 root volume (also holds the Magnolia repository)."
  type        = number
  default     = 30
}

variable "tomcat_version" {
  description = "Apache Tomcat 9.0.x version to install. Must stay on 9.x: Magnolia 6.2 uses javax.* servlet APIs."
  type        = string
  default     = "9.0.98"

  validation {
    condition     = can(regex("^9\\.0\\.[0-9]+$", var.tomcat_version))
    error_message = "tomcat_version must be a 9.0.x release (Tomcat 10+ is not compatible with Magnolia 6.2)."
  }
}

variable "java_package" {
  description = "Amazon Linux package providing the JRE."
  type        = string
  default     = "java-11-amazon-corretto-headless"
}

variable "magnolia_war_url" {
  description = "Download URL of the Magnolia Community Edition WAR. A .sha1 file must exist next to it."
  type        = string
  default     = "https://nexus.magnolia-cms.com/repository/magnolia.public.releases/info/magnolia/bundle/magnolia-community-demo-webapp/6.2/magnolia-community-demo-webapp-6.2.war"
}

variable "jvm_heap_mb" {
  description = "JVM heap size (-Xms and -Xmx) in MiB."
  type        = number
  default     = 1536
}

variable "magnolia_instance_type" {
  description = "Magnolia instance role: \"public\" serves anonymous visitors; \"author\" requires a login for every page (editors only)."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "author"], var.magnolia_instance_type)
    error_message = "magnolia_instance_type must be \"public\" or \"author\"."
  }
}

variable "expose_admin" {
  description = "Expose the Magnolia admin interface (/.magnolia) through Nginx. Keep false unless the default password was changed."
  type        = bool
  default     = false
}

variable "cloudfront_price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "cloudfront_prefix_list_id" {
  description = "Managed prefix list of CloudFront origin-facing IPs. Null looks it up by name."
  type        = string
  default     = null
}

variable "wait_for_cloudfront_deployment" {
  description = "Wait until the CloudFront distribution is fully deployed (several minutes on AWS)."
  type        = bool
  default     = true
}

variable "use_emulator" {
  description = "Run against an AWS emulator such as Floci (fake credentials, validation skipped). See examples/floci."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
