# 0011. Magnolia public instance by default, health check on the REST status endpoint
- Status: Accepted
- Date: 2026-10-14

## Context
The smoke test showed that the demo bundle started as an **author** instance (`magnolia.bootstrap.authorInstance=true`) answers HTTP 401 to every anonymous request except `/.rest/status`. Consequences for the AWS design:
- A visitor opening the CloudFront URL would get an authentication challenge; the only way in is Magnolia's default `superuser/superuser` account.
- The ALB health check on `/` (matcher 200-399) would fail, the target would stay unhealthy and CloudFront would return 503.
Magnolia's own model is an author instance for editors plus a public instance for visitors.

## Decision
- A variable `magnolia_instance_type` (`public` | `author`), default **`public`**. It writes `magnolia.bootstrap.authorInstance` during provisioning.
- Verified locally: on a public instance `/` redirects to `/travel.html` (relative Location, so it stays on the CloudFront host) and `/travel/` returns 200 ("Travel Home"). Anonymous browsing works and no default credentials are involved.
- The ALB health check path and the provisioning wait loop use **`/.rest/status`** (200 on both instance types, not blocked by Nginx), matcher `200`.

## Consequences
- Content cannot be edited on the public instance. A real project needs a separate author instance (private subnet, reached through SSM or a VPN) and replication to the public one. That is on the roadmap in the README.
- `magnolia_instance_type = "author"` remains available for demonstrations, but exposes a login-protected site with a known default account and should not face the internet.
- Magnolia logs a warning that `config:/server/defaultBaseUrl` is unset; absolute URLs generated for external systems are therefore not pinned to the CloudFront domain. Acceptable for the demo; to be set once a domain exists.

## Alternatives considered
- Keep the author instance and grant the anonymous role read access to the demo pages: requires editing Magnolia's JCR security configuration, fragile and not reproducible from properties alone.
- Health check on `/`: fails on author instances; `/travel.html` would tie the infrastructure to demo content.
