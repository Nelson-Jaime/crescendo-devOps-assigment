# 0005. Magnolia CE on Tomcat 9 + Nginx, provisioned with user_data
- Status: Accepted (versions confirmed by the Docker smoke test, see docs/evidence/smoke-test.txt)
- Date: 2026-10-14

## Context
The app must be installed automatically by Terraform: Tomcat + Magnolia CE, with Nginx reverse-proxying to it. Magnolia 6.2 is built on the `javax.*` servlet namespace.

## Decision
- **Magnolia:** `info.magnolia.bundle:magnolia-community-demo-webapp:6.2` (WAR) from Magnolia's public Nexus. The demo bundle shows real content, which makes the result easy to verify. Deployed as `ROOT.war` so the site is served at `/` with no path rewriting.
- **Tomcat 9.0.x**, not 10: Tomcat 10 moved to `jakarta.*` and would not run a `javax.*` application. Downloaded from Apache with SHA-512 verification.
- **Java:** Amazon Corretto **11**, a Java version Magnolia 6.2 supports, verified by the smoke test. Java 17 is not verified: a first attempt failed, but that run also had a different bug (see "Smoke test findings"), so the cause was never isolated. `JAVA_VERSION=17 make smoke` tests it.
- **Nginx** on :80 proxies to Tomcat bound to `127.0.0.1:8080`. Nginx sets forwarded headers; Tomcat's `RemoteIpValve` trusts them so Magnolia builds correct absolute URLs behind CloudFront.
- Provisioning uses `user_data` rendered by `templatefile()`: idempotent steps, `set -euo pipefail`, non-root service users, systemd units, logs to `/var/log/provision.log`. All versions are variables.

## Smoke test findings (what the local run changed)
- The Nexus WAR URL and its SHA-1 are valid for `magnolia-community-demo-webapp:6.2`.
- Magnolia creates only the last element of `magnolia.upload.tmpdir` and `magnolia.cache.startdir`. With nested paths that did not exist, the cache module crashed and every request returned HTTP 500. The provisioning script now creates `tmp/uploads` and `cache` first.
- Without `magnolia.update.auto=true` Magnolia waits for someone to click "Start installation" at `/.magnolia/installer`, a path Nginx blocks (ADR 0010). Automatic install is enabled.
- The Apache Tomcat tarball ships `bin/` and `conf/` as root-only (750) and `bin/*.sh` without the execute bit. The Debian smoke test never saw this (the official image fixes it); the Amazon Linux 2023 test did. The provisioning script now makes the install readable for the `tomcat` user and the scripts executable.
- An author instance answers 401 to anonymous visitors, so it cannot serve a public site and fails an ALB health check on `/` (ADR 0011).

A second test, `make al2023`, runs the rendered `user_data` script itself on Amazon Linux 2023 in Docker (the container has no systemd, so a `systemctl` stub reads the real unit file and starts Tomcat from it). It checks what the Debian-based smoke test cannot: `dnf` package names, the Tomcat download and checksum, users, permissions and a second run of the script.

## Consequences
- First boot takes a few minutes (downloads plus Magnolia bootstrap); the ALB health check has a generous grace period.
- Boot depends on the public Apache and Magnolia hosts being reachable through NAT.
- Changing `user_data` replaces the instance (`user_data_replace_on_change = true`), which is the honest behavior for immutable-style changes.

## Alternatives considered
- **Packer-baked AMI:** the better production approach (fast, reproducible, no runtime internet); listed in the roadmap, too heavy for a one-day exam.
- **Docker/ECS on the instance:** changes the stack the exam asked for (Tomcat + Nginx on EC2).
- **Ansible/cloud-init multi-file:** more structure than the size of the task justifies.
