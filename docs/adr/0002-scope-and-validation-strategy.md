# 0002. Scope: local validation instead of a live AWS deployment
- Status: Accepted
- Date: 2026-10-14

## Context
The exam asks for Magnolia running in AWS behind ALB and CloudFront, with screenshots of the CloudFront URL. Creating a new AWS account requires a payment card, and the author was not comfortable providing one for an assessment. The reviewer (Jeremy Summers, Crescendo Collective) replied on 2026-10-14 that local validation plus an end-to-end explanation or diagram is acceptable.

## Decision
Deliver production-shaped Terraform that is validated locally in three layers, and explain the real-AWS behavior in the README:
1. **Static checks:** `terraform fmt`, `validate`, tflint, in CI.
2. **Infrastructure apply against Floci** (open-source AWS emulator, endpoint override): proves the resource graph, references and provider usage work end to end at the API level.
3. **Application smoke test in Docker:** Nginx -> Tomcat 9 -> Magnolia CE using the exact config templates Terraform renders, proving the app layer and proxy headers.
The README and walkthrough describe the real request path (CloudFront -> ALB -> Nginx -> Tomcat) and list precisely what the emulator does not prove.

## Consequences
- No screenshot of a real `*.cloudfront.net` URL. Evidence is the local Magnolia page, Floci apply output and the diagram.
- Floci does not enforce security groups, real VPC routing or CloudFront delivery, and EC2 is a container. Those behaviors are documented as unverified rather than claimed.
- The code is not changed to suit the emulator; emulator-specific settings live in a separate `infra/examples/floci/` directory.

- In practice Floci could create and read back about 30 resources but not the EC2 instance or the CloudFront distribution (the AWS provider crashes on the emulator's CloudFront response). The apply is therefore scoped with `-target`, and the full `plan` remains the check for the whole graph. Details: `docs/validation-log.md`.

## Alternatives considered
- Real AWS with a personal card: rejected by the author; possible later without code changes.
- Reviewer-provided sandbox account: offered, the reviewer preferred local validation.
- LocalStack: needs an auth token for current versions; Floci is MIT-licensed and tokenless.
