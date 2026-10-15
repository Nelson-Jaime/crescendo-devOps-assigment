# Architecture Decision Records

Each ADR captures one significant decision: the context, what we chose, what we rejected and the consequences.
Format: lightweight [MADR](https://adr.github.io/madr/). Numbering is permanent; superseded ADRs stay in place and are marked.

| # | Decision | Status |
|---|----------|--------|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted |
| [0002](0002-scope-and-validation-strategy.md) | Scope: local validation instead of a live AWS deployment | Accepted |
| [0003](0003-network-topology.md) | VPC layout: 2 public + 2 private subnets, single NAT | Accepted |
| [0004](0004-compute-and-access.md) | One private EC2 instance, SSM instead of SSH | Accepted |
| [0005](0005-application-stack-and-provisioning.md) | Magnolia CE on Tomcat 9 + Nginx, provisioned with user_data | Accepted (verified by smoke test) |
| [0006](0006-edge-and-origin-protection.md) | CloudFront -> ALB, origin locked down by prefix list + secret header | Accepted |
| [0007](0007-cloudfront-caching-and-headers.md) | CloudFront cache and header-forwarding policy | Accepted |
| [0008](0008-terraform-structure-and-state.md) | Terraform layout, version pinning and state handling | Accepted |
| [0009](0009-ci-pipeline.md) | GitHub Actions: fmt, validate, plan, plus Floci apply | Accepted |
| [0010](0010-admin-interface-exposure.md) | Magnolia admin (`/.magnolia`) blocked by default | Accepted |
| [0011](0011-public-instance-and-health-check.md) | Public Magnolia instance by default; health check on `/.rest/status` | Accepted |

## Template

```
# NNNN. Title
- Status: Proposed | Accepted | Superseded by NNNN
- Date: YYYY-MM-DD
## Context
## Decision
## Consequences
## Alternatives considered
```
