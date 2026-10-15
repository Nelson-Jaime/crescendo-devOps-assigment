# 0007. CloudFront cache and header-forwarding policy
- Status: Accepted
- Date: 2026-10-14

## Context
Magnolia is a CMS: pages can be personalised or edited, admin traffic uses POST/PUT and cookies, and the application must know the original scheme and host to build correct URLs.

## Decision
- **Default behavior:** all HTTP methods allowed, managed `CachingDisabled` policy. Correctness first; nothing dynamic is cached by accident.
- **Static paths** (`/.resources/*`, `/dam/*`, `/docroot/*`): managed `CachingOptimized`, compression on.
- **Origin request policy:** forwards viewer headers, cookies and query strings plus CloudFront viewer headers (`CloudFront-Forwarded-Proto`). Nginx maps `CloudFront-Forwarded-Proto` to `X-Forwarded-Proto`.
- Price class 100, IPv6 on, HTTP/2 and HTTP/3.
- AWS managed policies are referenced by their documented, stable IDs (CachingDisabled, CachingOptimized, AllViewerAndCloudFrontHeaders-2022-06), with the policy name in a comment. This avoids a lookup that also works in the emulator.

## Consequences
- Low cache hit ratio for dynamic pages at first; a conscious trade-off. Tuning (cache keys per page type, TTLs from Magnolia headers) is roadmap work that needs real traffic data.
- Forwarding all cookies means authenticated and anonymous traffic never share a cache entry on the default behavior.

## Alternatives considered
- Cache everything with a short TTL: risks serving stale or personalised content.
- No CloudFront static behaviors: simplest, but wastes the main benefit of a CDN.
