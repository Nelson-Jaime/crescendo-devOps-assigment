# Validation log

What was tested locally, what failed, and what each failure changed. Raw output: `docs/evidence/smoke-test.txt`.
Context: no AWS account was used ([ADR 0002](adr/0002-scope-and-validation-strategy.md)), so the application layer was tested in Docker with the same config files Terraform ships to the instance.

## Smoke test findings (Nginx -> Tomcat 9 -> Magnolia CE 6.2)

| # | Symptom | Root cause | Change |
|---|---------|------------|--------|
| 1 | Every path returned Tomcat 404 for 15 min; log: "Magnolia could not be started" | First run used Java 17; the log did not show the underlying exception, and the container was deleted before it could be read. Cause **not isolated** (finding 3 was present in the same run) | The test now keeps diagnostics on failure (Java version, direct Tomcat probes, full Magnolia logs) and stops early. Java 11 (supported by Magnolia 6.2) is the tested default; Java 17 is untested |
| 2 | `/` redirected to `/.magnolia/installer` and stayed there | Magnolia waits for someone to click "Start installation"; that path is blocked by Nginx ([ADR 0010](adr/0010-admin-interface-exposure.md)), so on EC2 nobody could ever finish it | `magnolia.update.auto=true` |
| 3 | Every request returned HTTP 500 after enabling auto-install; log: `Can't create temporary directory under path [/var/lib/magnolia/tmp/uploads]` | Magnolia creates only the last path element; parent directories did not exist. The cache module crashed during startup | `tmp/uploads` and `cache` created in the provisioning script and the Dockerfile (**this bug was also in the EC2 script**) |
| 4 | Everything returned 401 except `/.rest/status` | The demo bundle starts as an **author** instance, which refuses anonymous visitors. On AWS the ALB health check on `/` would have failed (503) and the only way in would be the default `superuser` account | `magnolia_instance_type = "public"` by default, health check and wait loop on `/.rest/status` ([ADR 0011](adr/0011-public-instance-and-health-check.md)) |

Final result (Java 11, public instance): `/.rest/status` 200 about 20 s after start, `/` -> 302 `/travel.html`, `/travel/` 200 "Travel Home", `/.magnolia/` 403, redirects stay relative behind `CloudFront-Forwarded-Proto: https`, repository written under `/var/lib/magnolia`.

## Amazon Linux 2023 provisioning test (`make al2023`)

| # | Symptom | Root cause | Change |
|---|---------|------------|--------|
| 5 | First run: `provision.sh` stopped after "configuring Nginx": `/opt/tomcat/bin/catalina.sh: Permission denied` (still after adding a `chmod +x`) | Two causes in the Apache Tomcat tarball: `bin/*.sh` has **no execute bit**, and `bin/` and `conf/` are mode 750 root-only, so the unprivileged `tomcat` user cannot even traverse into `bin/`. The Debian smoke test never saw it because the official `tomcat` image fixes the modes. **This would have failed on the real instance too** | `chmod -R go+rX` on the install and `chmod 0755 bin/*.sh` in `provision.sh.tpl` |
| 6 | `nginx -t` warning: `could not build optimal types_hash` | AL2023's `mime.types` is larger than Nginx's default hash size | `types_hash_max_size 4096;` in `nginx.conf` |

Result after fixes 5 and 6 (Amazon Linux 2023.12, aarch64, Corretto 11.0.32, Nginx 1.30, Tomcat 9.0.98): `provision.sh` exited 0 in about 2 minutes (most of it `dnf` and downloads) and every check passed: Tomcat runs as `tomcat` and listens on loopback only, `/.rest/status` 200 and `/travel/` 200 through Nginx, `/.magnolia/` 403, no http downgrade behind `CloudFront-Forwarded-Proto: https`, repository under `/var/lib/magnolia` owned by `tomcat`, and a second run of the script exits 0 without appending the overrides again or starting a second Tomcat. Raw output: `docs/evidence/al2023-provision-test.txt`.

## Floci (AWS emulator) apply

First full `terraform apply` against Floci: **about 30 resources created and read back correctly** (VPC, 4 subnets, IGW, NAT gateway and EIP, route tables and associations, default SG, IAM role/profile/policy attachment, both security groups with their ingress/egress rules, ALB, target group, listener, `random_password`). Three resources did not complete:

| Resource | Failure | Cause |
|---|---|---|
| `aws_cloudfront_distribution` | Provider crash: `nil pointer dereference` in `flattenDefaultCacheBehavior` while reading the distribution back after creation | The emulator's CloudFront response is incomplete; the provider (5.100.0) does not tolerate it. Not a configuration error: the same block is valid for AWS |
| `aws_instance` | `collecting instance settings: empty result` | The emulator returns no instance settings when the provider reads them back |
| `aws_lb_target_group_attachment` | not attempted | Depends on the instance |
| `aws_lb_listener_rule` | "Request cancelled" | Cancelled by the CloudFront crash, not an error of its own: **created successfully in the targeted run** |

A second emulator quirk showed up when destroying: refreshing the state makes the provider report `Provider produced invalid plan ... "requires replacement" ... for a non-existent attribute path` on the two ingress rules that use a referenced security group or a prefix list (`from_alb`, `from_cloudfront`). Floci reads those rules back in a shape the provider cannot reconcile; the egress rules (CIDR based) refresh fine. The emulator scripts therefore use `-refresh=false` and a separate `floci.tfstate`, which also keeps them away from any real state.

A third quirk: Floci does not support `TagInstanceProfile` and returns no IAM tags on read. Creating the role and profile works (tags are sent at creation), but applying again on an existing state plans a `tags_all` update and fails with `UnsupportedOperation`. Hence "apply once per clean state" in `infra/examples/floci/README.md`; CI always starts from an empty emulator.

A fourth quirk, seen only once the stack ran in GitHub Actions (pulling `floci/floci:latest` fresh, vs. the pinned-by-accident local image used for the counts above): creating `module.alb.aws_vpc_security_group_ingress_rule.from_cloudfront` now fails with `InvalidPrefixListID.NotFound: The prefix list ID 'pl-00000000' does not exist`, because `floci.tfvars` sets `cloudfront_prefix_list_id` to a placeholder (the real `com.amazonaws.global.cloudfront.origin-facing` list doesn't exist in the emulator either, so a lookup by name isn't an option). This resource created successfully in earlier local runs, so the emulator's validation of prefix-list references appears to have tightened between image builds. The targeted apply no longer includes this resource; it's a Floci limitation, not a configuration error (the same block is valid for AWS).

Final state: the targeted apply creates **31 resources** (the first run's 30 plus the instance security group's `from_alb` ingress rule; `from_cloudfront` is excluded per the fourth quirk above), and `make floci-destroy` removes them all cleanly; `make floci-down` then removes the container and the state file.

Decision: the real code is not changed to suit the emulator ([ADR 0002](adr/0002-scope-and-validation-strategy.md)). `make floci-apply` applies the supported subset with `-target`; `FULL=1 make floci-apply` tries the whole stack again. The CI job runs a full `plan` against Floci (which exercises every resource and reference) and the subset apply.

## GitHub Actions

The workflow ran on a test pull request (`test/ci-verify`) and passed: `fmt, validate, tflint` (28 s) and `plan against Floci` (full plan plus the subset apply, 1 m 40 s) succeeded; `plan against AWS (optional)` was skipped as designed. Screenshot: `docs/evidence/ci-run-green.webp`. The only annotations were runner notices (Node.js 20 action deprecation, and `ubuntu-latest` moving to Ubuntu 26 on 2026-10-19), which is why the jobs now pin `ubuntu-24.04`.

## Static checks
`terraform init -backend=false` + `terraform validate` (Terraform with AWS provider 5.100.0 and random 3.9.1: "The configuration is valid"), `terraform fmt`, tflint (terraform + aws rulesets), shellcheck on all scripts and on the rendered `user_data` (`docker/al2023/render.py` renders the template the way `templatefile()` does), workflow YAML parse.

## Not verified locally
- The optional real-AWS `plan` job (`plan-aws`): skipped by design because no `AWS_ROLE_ARN` is configured.
- Floci coverage of the EC2 instance, the target-group attachment and CloudFront (see above).
- The Amazon Linux 2023 provisioning path: `make al2023` (docker/al2023) runs the rendered `user_data` script in an AL2023 container with a `systemctl` stub (passing, see above). Still not covered: a real boot with systemd and cloud-init, and the unit's sandboxing options (`PrivateTmp`, `ProtectSystem`, `NoNewPrivileges`).
- Everything that needs real AWS: security-group enforcement, ALB to instance traffic, CloudFront delivery, the secret-header rule.
- Java 17 (`JAVA_VERSION=17 make smoke`).
