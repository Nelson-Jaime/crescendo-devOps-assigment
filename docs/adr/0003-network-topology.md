# 0003. VPC layout: 2 public + 2 private subnets, single NAT
- Status: Accepted
- Date: 2026-10-14

## Context
Required: VPC, 2 public + 2 private subnets in different AZs, IGW, NAT gateway, route tables. An ALB needs subnets in at least two AZs. Only one EC2 instance is required.

## Decision
- One /16 VPC; four /24 subnets (public and private in each of two AZs), derived with `cidrsubnet()`; AZs from a data source, not hard-coded.
- Public route table -> Internet Gateway. Private route table -> NAT gateway in a public subnet.
- A single NAT gateway by default, controlled by `single_nat_gateway` (true/false).
- The ALB uses both public subnets; the instance runs in private subnet A. Private subnet B is intentionally empty and reserved for an Auto Scaling group.

## Consequences
- The NAT gateway is the largest fixed cost of the stack and a single-AZ failure point; acceptable for a demo, documented as a limitation. Setting `single_nat_gateway = false` creates one per AZ.
- Instances have no public IPs; outbound internet (package and WAR downloads) goes only through NAT.

## Alternatives considered
- Community `terraform-aws-modules/vpc`: faster, but hides the logic reviewers want to read. Kept as a fallback.
- VPC endpoints instead of NAT: cheaper at scale, but the instance needs the public internet for Apache and Magnolia downloads, and the exam explicitly requires a NAT gateway.
