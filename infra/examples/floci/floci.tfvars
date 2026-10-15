# Settings for running the stack against the Floci AWS emulator (see examples/floci/README.md).
use_emulator                   = true
aws_region                     = "us-east-1"
ami_id                         = "ami-0123456789abcdef0" # the emulator maps AMIs to container images
cloudfront_prefix_list_id      = "pl-00000000"           # the managed prefix list does not exist in the emulator
wait_for_cloudfront_deployment = false
