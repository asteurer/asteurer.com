.PHONY: plan show apply destroy ssh

# OPTIONAL: You don't have to use the 1Password CLI, but can instead use plaintext or env vars
DO_TOKEN := $(shell op item get digital_ocean --vault Prod --fields label=credential --reveal)
CF_TOKEN := $(shell op item get cloudflare --vault Prod --fields label=credential --reveal)
CF_ZONE := $(shell op item get cloudflare --vault Prod --fields label=zone_id --reveal)
CF_DOMAIN := $(shell op item get cloudflare --vault Prod --fields label=url --reveal)
CF_EMAIL := $(shell op item get cloudflare --vault Prod --fields label=email --reveal)
AWS_REGION := us-west-2
PROJECT_NAME := demo

# OPTIONAL: Update awk command with the name of your SSH public key
FINGERPRINT := $(shell doctl compute ssh-key list | awk '/main/ {print $$3}')

# This ensures that the init.yaml file is present for all terraform commands
IGNORE := $(shell echo "" > init.yaml)

apply: plan
	terraform apply --auto-approve "tfplan"

show: plan
	terraform show --json "tfplan" | jq > tfplan.json

plan:
	DOMAIN="$(CF_DOMAIN)" \
	PROJECT_NAME="$(PROJECT_NAME)" \
	AWS_REGION="$(AWS_REGION)" \
	EMAIL=$(CF_EMAIL) \
	go run parse_template.go

	terraform plan --out tfplan \
		--var="do_token=$(DO_TOKEN)" \
		--var="ssh_key_fingerprint=$(FINGERPRINT)" \
		--var="cloudflare_api_token=$(CF_TOKEN)" \
		--var="cloudflare_zone_id=$(CF_ZONE)" \
		--var="aws_region=$(AWS_REGION)" \
		--var="domain=$(CF_DOMAIN)"

destroy:
	terraform destroy --auto-approve \
		--var="do_token=$(DO_TOKEN)" \
		--var="ssh_key_fingerprint=$(FINGERPRINT)" \
		--var="cloudflare_api_token=$(CF_TOKEN)" \
		--var="cloudflare_zone_id=$(CF_ZONE)" \
		--var="aws_region=$(AWS_REGION)" \
		--var="domain=$(CF_DOMAIN)"

ssh:
	@DROPLET_IP=$(shell terraform output --json | jq -r '.droplet_ipv4.value'); \
	if [ -z "$$DROPLET_IP" ]; then \
		echo "Error: Droplet IP not found."; \
		exit 1; \
	else \
		ssh root@$$DROPLET_IP; \
	fi