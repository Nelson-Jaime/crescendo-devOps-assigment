# 0006. CloudFront -> ALB, origin locked down by prefix list + secret header
- Status: Accepted
- Date: 2026-10-14

## Context
The ALB is internet-facing (CloudFront must reach it), but only CloudFront should be able to use it. No custom domain exists, so there is no ACM certificate for the ALB.

## Decision
Defense in depth on the path CloudFront -> ALB -> EC2:
1. **ALB security group** allows port 80 only from the AWS-managed CloudFront origin-facing prefix list.
2. **Secret header:** CloudFront adds `X-Origin-Verify: <random>` (generated with `random_password`); the ALB listener's default action is a fixed 403, and a rule forwards only requests carrying the header. The prefix list alone would still admit any CloudFront distribution in the world.
3. **EC2 security group** allows port 80 only from the ALB security group.
4. CloudFront uses the default `*.cloudfront.net` certificate (HTTPS to viewers, redirect HTTP to HTTPS).

## Consequences
- **Known limitation:** CloudFront -> ALB is plain HTTP, since there is no domain/ACM certificate. The secret header therefore crosses AWS's network unencrypted. With a domain: ACM certificate on the ALB and origin protocol policy `https-only`.
- The CloudFront prefix list consumes many security-group rule slots (about 55 of the default 60); fine here, worth knowing at scale.
- The secret is stored in Terraform state; state must be treated as sensitive (see ADR 0008). Rotation means re-applying.

## Alternatives considered
- Prefix list only: simpler but spoofable by other CloudFront distributions.
- ALB open to the internet: rejected.
- WAF in front of the ALB: valid hardening step, out of scope for the time box (roadmap).
