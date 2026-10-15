# 0004. One private EC2 instance, SSM instead of SSH
- Status: Accepted
- Date: 2026-10-14

## Context
One EC2 instance in a private subnet must run Tomcat, Magnolia CE and Nginx. Operators still need shell access for debugging.

## Decision
- Amazon Linux 2023 (latest x86_64 AMI resolved with an `aws_ami` data source, not a hard-coded ID; `ami_id` can pin it; `ignore_changes = [ami]` stops a newer image from silently replacing a running instance), `t3.medium` by default (variable). Magnolia is memory hungry; 4 GiB leaves room for a ~1.5 GiB heap plus the OS and Nginx.
- No public IP, no key pair, no port 22. Access through **SSM Session Manager** with an instance profile (`AmazonSSMManagedInstanceCore`).
- IMDSv2 required (`http_tokens = required`), encrypted root volume (gp3).
- Content lives under `/var/lib/magnolia`, outside the webapp directory, so a redeploy of the WAR keeps the repository.

## Consequences
- Smaller attack surface and no key management. Auditing is available through Session Manager logging.
- SSM needs outbound access to the SSM endpoints; satisfied by the NAT gateway (interface endpoints would be the next step).
- A single instance with local disk is a single point of failure; see the roadmap in the README (ASG, baked AMI, RDS).

## Alternatives considered
- Bastion host with SSH: more moving parts and an exposed port.
- Ubuntu: equally valid; AL2023 chosen for Corretto in the default repositories and SSM agent preinstalled.
