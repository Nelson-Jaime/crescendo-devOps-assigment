locals {
  name_prefix = "${var.project}-${var.environment}"

  default_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  # ALB requires two AZs; the layout is two public + two private subnets.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Shared secret: CloudFront adds it as a header, the ALB only forwards requests that carry it (ADR 0006).
resource "random_password" "origin_verify" {
  length  = 40
  special = false
}

module "network" {
  source = "./modules/network"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  azs                = local.azs
  single_nat_gateway = var.single_nat_gateway
}

module "alb" {
  source = "./modules/alb"

  name_prefix               = local.name_prefix
  vpc_id                    = module.network.vpc_id
  vpc_cidr                  = var.vpc_cidr
  public_subnet_ids         = module.network.public_subnet_ids
  origin_verify_secret      = random_password.origin_verify.result
  cloudfront_prefix_list_id = var.cloudfront_prefix_list_id
  target_instance_id        = module.compute.instance_id
}

module "compute" {
  source = "./modules/compute"

  name_prefix            = local.name_prefix
  vpc_id                 = module.network.vpc_id
  subnet_id              = module.network.private_subnet_ids[0]
  alb_security_group_id  = module.alb.security_group_id
  ami_id                 = var.ami_id
  instance_type          = var.instance_type
  root_volume_size_gb    = var.root_volume_size_gb
  tomcat_version         = var.tomcat_version
  java_package           = var.java_package
  magnolia_war_url       = var.magnolia_war_url
  jvm_heap_mb            = var.jvm_heap_mb
  expose_admin           = var.expose_admin
  magnolia_instance_type = var.magnolia_instance_type
}

module "cloudfront" {
  source = "./modules/cloudfront"

  name_prefix          = local.name_prefix
  origin_domain_name   = module.alb.dns_name
  origin_verify_secret = random_password.origin_verify.result
  price_class          = var.cloudfront_price_class
  wait_for_deployment  = var.wait_for_cloudfront_deployment
}
