# 0008. Terraform layout, version pinning and state handling
- Status: Accepted
- Date: 2026-10-14

## Context
Code quality and organization are explicit evaluation criteria. The stack has four natural boundaries.

## Decision
- All Terraform lives in `infra/` (application tests and docs stay outside it). The root module wires four small local modules: `network`, `compute`, `alb`, `cloudfront`. Modules expose a minimal interface through typed, documented variables with validation, and outputs only what consumers need.
- `required_version >= 1.10`; AWS provider pinned to a major version; `.terraform.lock.hcl` committed.
- `default_tags` on the provider (project, environment, managed-by); consistent `name_prefix`.
- **State:** the main code ships with a documented S3 backend example (`infra/backend.tf.example`: versioned, encrypted bucket, native lockfile locking) and defaults to local state, since there is no real account. State files and `*.tfvars` are git-ignored.
- Tooling: pre-commit (`terraform fmt`, `validate`, tflint, terraform-docs).

## Consequences
- Reviewers can read each concern in isolation. Slightly more files than a single `main.tf`, but each is short.
- Local state is acceptable for a demo only; the README states the remote-state setup for real use.
- State holds the origin secret and must not be committed or shared.

## Alternatives considered
- Single flat `main.tf`: quick but weak on organization.
- Public community modules everywhere: less code, less to demonstrate; used only as a fallback.
- Workspaces or per-environment directories: unnecessary for one environment, noted in the roadmap.
