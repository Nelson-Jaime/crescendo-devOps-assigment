#!/usr/bin/env bash
# Applies the whole stack against a local Floci emulator, shows the outputs and destroys it again.
# Usage: infra/examples/floci/run.sh [apply|plan|destroy]   Requires Docker and Terraform >= 1.10.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="${1:-apply}"
ENDPOINT="http://localhost:4566"
cd "$ROOT"

if ! (exec 3<>/dev/tcp/127.0.0.1/4566) 2>/dev/null; then
  echo "Starting Floci on :4566 ..."
  docker run -d --name floci -p 4566:4566 \
    -v /var/run/docker.sock:/var/run/docker.sock -u root floci/floci:latest >/dev/null
  sleep 5
fi

export AWS_ENDPOINT_URL="$ENDPOINT" AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1
TF_ARGS=(-var-file=examples/floci/floci.tfvars)

# Floci cannot complete four resources (details in docs/validation-log.md): the EC2 instance (it returns no instance
# settings), the target-group attachment (needs the instance), the CloudFront distribution (the AWS provider panics
# on the emulator's response), and the CloudFront-prefix-list ingress rule (floci.tfvars' cloudfront_prefix_list_id
# is a placeholder; Floci rejects AuthorizeSecurityGroupIngress against a prefix list that doesn't exist in its
# backend). `apply` therefore targets everything else. FULL=1 applies the whole stack.
TARGETS=(
  -target=module.network
  -target=module.alb.aws_lb_listener_rule.origin_verified
  -target=module.alb.aws_vpc_security_group_egress_rule.to_targets
  -target=module.compute.aws_vpc_security_group_ingress_rule.from_alb
  -target=module.compute.aws_vpc_security_group_egress_rule.https
  -target=module.compute.aws_vpc_security_group_egress_rule.http
  -target=module.compute.aws_iam_role_policy_attachment.ssm
  -target=module.compute.aws_iam_instance_profile.instance
)
if [ "${FULL:-0}" = 1 ]; then TARGETS=(); fi

# The emulator is disposable, so it gets its own state file (never the real one) and no refresh: the AWS provider
# cannot reconcile Floci's read-back of security-group rules that use a referenced SG or a prefix list ("Provider
# produced invalid plan"), which breaks any plan on an existing state. See docs/validation-log.md.
STATE=(-state=floci.tfstate -refresh=false)

terraform init -input=false
terraform validate
case "$MODE" in
  plan)    terraform plan -input=false "${TF_ARGS[@]}" "${STATE[@]}" ;;
  apply)   terraform apply -input=false -auto-approve "${TF_ARGS[@]}" "${STATE[@]}" "${TARGETS[@]}" \
             && terraform state list -state=floci.tfstate | wc -l | xargs echo "resources in state:" ;;
  destroy) terraform destroy -input=false -auto-approve "${TF_ARGS[@]}" "${STATE[@]}" ;;
  *) echo "unknown mode: $MODE" >&2; exit 2 ;;
esac
