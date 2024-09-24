.PHONY: plan show apply destroy ssh

# OPTIONAL: You don't have to use the 1Password CLI, but can instead use plaintext or env vars
DO_TOKEN := $(shell op item get digital_ocean --vault Prod --fields label=credential --reveal)
CF_DATA := $(shell op item get cloudflare --vault Prod --fields label=credential,label=zone_id,label=url,label=email --format json --reveal)
CF_TOKEN := $(shell printf '%s\n' '$(CF_DATA)' | jq -r '.[] | select(.label == "credential") | .value')
CF_ZONE := $(shell printf '%s\n' '$(CF_DATA)' | jq -r '.[] | select(.label == "zone_id") | .value')
CF_DOMAIN := $(shell printf '%s\n' '$(CF_DATA)' | jq -r '.[] | select(.label == "url") | .value')
CF_EMAIL := $(shell printf '%s\n' '$(CF_DATA)' | jq -r '.[] | select(.label == "email") | .value')
AWS_REGION := us-west-2
PROJECT_NAME := demo

# OPTIONAL: Update awk command with the name of your SSH public key
FINGERPRINT := $(shell doctl compute ssh-key list | awk '/main/ {print $$3}')

# This ensures that the init.yaml file is present for all terraform commands
IGNORE := $(shell echo "" > init.yaml)

TF_VARS := \
	--var="do_token=$(DO_TOKEN)" \
	--var="ssh_key_fingerprint=$(FINGERPRINT)" \
	--var="cloudflare_api_token=$(CF_TOKEN)" \
	--var="cloudflare_zone_id=$(CF_ZONE)" \
	--var="aws_region=$(AWS_REGION)" \
	--var="domain=$(CF_DOMAIN)"

apply: plan
	terraform apply --auto-approve "tfplan"

show: plan
	terraform show --json "tfplan" | jq > tfplan.json

plan:
	@DOMAIN="$(CF_DOMAIN)" \
	PROJECT_NAME="$(PROJECT_NAME)" \
	AWS_REGION="$(AWS_REGION)" \
	EMAIL=$(CF_EMAIL) \
	go run parse_template.go

	@terraform plan --out tfplan $(TF_VARS)

destroy:
	@terraform destroy --auto-approve $(TF_VARS)

# Should you ever lose the terraform state files, you can run this command
recover:
	@terraform import \
		$(TF_VARS) \
		digitalocean_droplet.demo_server \
		$$(doctl compute droplet list | awk '/demo-server/ {print $$1}')

	@DATA=$$(curl -X GET "https://api.cloudflare.com/client/v4/zones/$(CF_ZONE)/dns_records" -H "Authorization: Bearer $(CF_TOKEN)" -H "Content-Type: application/json"); \
	terraform import \
		$(TF_VARS) \
		cloudflare_record.root $(CF_ZONE)/$$(echo $$DATA | jq -r '.result[] | select(.name == "$(CF_DOMAIN)") | .id'); \
	terraform import \
		$(TF_VARS) \
		cloudflare_record.www $(CF_ZONE)/$$(echo $$DATA | jq -r '.result[] | select(.name == "www.$(CF_DOMAIN)") | .id')

	@terraform import \
		$(TF_VARS) \
		aws_s3_bucket.static_files \
		"$(CF_DOMAIN)-static-files"

	@terraform import \
		$(TF_VARS) \
		aws_s3_bucket_public_access_block.static_files \
		"$(CF_DOMAIN)-static-files"

	@terraform import \
		$(TF_VARS) \
		aws_s3_bucket_policy.static_files \
		"$(CF_DOMAIN)-static-files"


ssh:
	@DROPLET_IP=$(shell terraform output --json | jq -r '.droplet_ipv4.value'); \
	if [ -z "$$DROPLET_IP" ]; then \
		echo "Error: Droplet IP not found."; \
		exit 1; \
	else \
		ssh root@$$DROPLET_IP; \
	fi