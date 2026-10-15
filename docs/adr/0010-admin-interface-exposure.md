# 0010. Magnolia admin (`/.magnolia`) blocked by default
- Status: Accepted
- Date: 2026-10-14

## Context
Magnolia ships with a default `superuser/superuser` account, and the admin UI lives under `/.magnolia/`. Exposing it to the whole internet through CloudFront on a demo stack is an easy way to get compromised.

## Decision
Nginx returns 403 for `/.magnolia/` by default. A variable `expose_admin` (default `false`) removes the block. Recommended access path when needed: SSM port-forward to the instance (or temporarily enable the variable and change the default password immediately).

## Consequences
- Safe by default; the public site and the demo content still load through CloudFront.
- Slightly more friction for editors; a production setup would expose a separate, access-controlled author instance (roadmap).

- With the default public instance (ADR 0011) the admin UI is not needed for visitors, so the block costs nothing. Editing content requires an author instance, reached through SSM port forwarding.

## Alternatives considered
- Leave it open and document the risk: rejected, insecure default.
- Block in CloudFront or WAF: also valid; Nginx keeps the rule next to the application config and testable in the local Docker smoke test.
