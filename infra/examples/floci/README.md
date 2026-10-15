# Running the stack against Floci

[Floci](https://floci.io) is an open-source (MIT) AWS emulator. This directory contains the settings that switch the root module into emulator mode (`use_emulator = true`): fake credentials, no AWS-side validation, and endpoints taken from `AWS_ENDPOINT_URL`.

```bash
make floci-apply      # starts Floci on :4566 if needed, then init + validate + apply of the supported subset
FULL=1 make floci-apply   # tries the whole stack (EC2 and CloudFront currently fail in the emulator)
make floci-destroy   # destroys from state without refreshing (see docs/validation-log.md)
make floci-down       # removes the Floci container
```

Apply once per clean state. Floci does not support tagging IAM instance profiles and does not return IAM tags on read, so a second `apply` on an existing `floci.tfstate` shows a `tags_all` diff and fails with `TagInstanceProfile is not supported`. Run `make floci-destroy floci-down` first for a fresh run (CI always starts clean).

Requirements: Docker (EC2 in the emulator launches containers through the Docker socket) and Terraform >= 1.10.

What this does and does not prove is listed in the main README and [ADR 0002](../../../docs/adr/0002-scope-and-validation-strategy.md). In short: it exercises the resource graph and provider calls, not real networking or CloudFront delivery.
