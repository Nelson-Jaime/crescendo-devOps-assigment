provider "aws" {
  region = var.aws_region

  # Emulator mode (Floci, see examples/floci): fake credentials and no AWS-side
  # validation. Endpoints are taken from the AWS_ENDPOINT_URL environment variable.
  access_key                  = var.use_emulator ? "test" : null
  secret_key                  = var.use_emulator ? "test" : null
  skip_credentials_validation = var.use_emulator
  skip_metadata_api_check     = var.use_emulator
  skip_requesting_account_id  = var.use_emulator
  skip_region_validation      = var.use_emulator

  default_tags {
    tags = local.default_tags
  }
}
