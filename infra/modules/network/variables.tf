variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR of the VPC (/16)."
  type        = string
}

variable "azs" {
  description = "Availability zones to spread subnets over (at least two)."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "At least two availability zones are required."
  }
}

variable "single_nat_gateway" {
  description = "One shared NAT gateway instead of one per AZ."
  type        = bool
  default     = true
}
