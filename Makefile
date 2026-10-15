.PHONY: help fmt fmt-check validate lint smoke al2023 floci-plan floci-apply floci-destroy floci-down

INFRA := infra

help: ## Show targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

fmt: ## Format all Terraform files
	terraform -chdir=$(INFRA) fmt -recursive

fmt-check: ## Check formatting (CI)
	terraform -chdir=$(INFRA) fmt -check -recursive

validate: ## terraform init (no backend) and validate
	terraform -chdir=$(INFRA) init -backend=false -input=false
	terraform -chdir=$(INFRA) validate

lint: ## tflint on root and modules
	tflint --init --chdir=$(INFRA)
	tflint --recursive --chdir=$(INFRA)

smoke: ## Docker smoke test: Nginx -> Tomcat 9 -> Magnolia CE (writes docs/evidence/smoke-test.txt)
	docker/smoke/test.sh

al2023: ## Run the EC2 user_data script on Amazon Linux 2023 in Docker (writes docs/evidence/al2023-provision-test.txt)
	docker/al2023/test.sh

floci-plan: ## terraform plan against the Floci emulator
	$(INFRA)/examples/floci/run.sh plan

floci-apply: ## terraform apply against the Floci emulator
	$(INFRA)/examples/floci/run.sh apply

floci-destroy: ## terraform destroy against the Floci emulator
	$(INFRA)/examples/floci/run.sh destroy

floci-down: ## Stop and remove the Floci container and its local state file
	-docker rm -f floci
	rm -f $(INFRA)/floci.tfstate $(INFRA)/floci.tfstate.backup
