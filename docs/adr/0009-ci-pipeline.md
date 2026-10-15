# 0009. GitHub Actions: fmt, validate, plan, plus Floci apply
- Status: Accepted
- Date: 2026-10-14

## Context
The exam requires a workflow running `terraform fmt`, `validate` and `plan` on pull requests. The repository is public and there is no AWS account to authenticate against.

## Decision
One workflow, triggered on `pull_request` (path-filtered to Terraform files):
1. **fmt:** `terraform fmt -check -recursive`.
2. **validate:** `terraform init -backend=false` then `terraform validate`, plus tflint and a non-blocking Trivy config scan.
3. **plan (Floci):** start Floci as a service container and run `plan` (required) and `apply` (informational until emulator coverage is proven) against it with `infra/examples/floci/floci.tfvars` and the `use_emulator` variable. No secrets are needed.
4. **plan (real AWS, optional):** runs only if the repository variable `AWS_ROLE_ARN` is set, using GitHub OIDC with a read-only role. Skipped cleanly otherwise (forks, no account).
The real-AWS plan is written to the job summary. Hardening: least-privilege `permissions`, `concurrency` to cancel superseded runs, pinned action versions, never `pull_request_target`.

## Consequences
- Every PR gets a real `plan` with zero credentials; the Floci job exercises dependencies, not just syntax.
- The Floci plan is not a perfect proxy for AWS (see ADR 0002); the optional real-AWS job closes that gap when an account exists.
- No long-lived AWS keys exist anywhere in the repository.

## Alternatives considered
- Static access keys in secrets: rejected, long-lived credentials in a public repo's CI.
- `fmt` and `validate` only: does not meet the "plan" requirement.
