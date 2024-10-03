.PHONY: tf-apply tf-show tf-plan tf-destroy tfvars nginx-ssh nginx-show-ip nginx-get-ip nginx-init nginx-config nginx-update-html store

CF_DOMAIN := asteurer.com
AWS_REGION := us-west-2
OP_VAULT := Prod

# Deploy the infrastructure
tf-apply: tf-plan
	@terraform apply --auto-approve "tfplan"

# Show the plan for the infrastructure
tf-show: tf-plan
	@terraform show --json "tfplan" | jq > tfplan.json

# Plan the infrastructure
tf-plan: tfvars
	@terraform plan --out tfplan $(TF_VARS)

# Destroy the infrastructure
tf-destroy: tfvars
	@terraform destroy --auto-approve $(TF_VARS)

# Export the TFVARS variable to be used by other make commands
tfvars:
	@$(eval SSH_KEY := $(shell op item get ec2_$(CF_DOMAIN) --vault $(OP_VAULT) --fields label="public key"))
	@$(eval CF_DATA := $(shell op item get cloudflare_$(CF_DOMAIN) --vault $(OP_VAULT) --fields label=credential,label=zone_id --format json --reveal))
	@$(eval CF_TOKEN := $(shell printf '%s\n' '$(CF_DATA)' | jq -r '.[] | select(.label == "credential") | .value'))
	@$(eval CF_ZONE := $(shell printf '%s\n' '$(CF_DATA)' | jq -r '.[] | select(.label == "zone_id") | .value'))
	@$(eval TF_VARS := \
		--var="aws_region=$(AWS_REGION)" \
		--var="ssh_public_key=$(SSH_KEY)" \
		--var="cloudflare_domain=$(CF_DOMAIN)" \
		--var "cloudflare_zone_id=$(CF_ZONE)" \
		--var "cloudflare_api_token=$(CF_TOKEN)"\
	)

# SSH into the EC2 instance
nginx-ssh: nginx-get-ip
	@ssh ubuntu@$(IP_ADDR_NGINX)

# Show the IP address of the EC2 instance
nginx-show-ip: nginx-get-ip
	@echo $(IP_ADDR_NGINX)

# Export the IP address of the EC2 instance to be used by other make commands
nginx-get-ip:
	@$(eval IP_ADDR_NGINX := $(shell terraform  output --json | jq -r '.nginx_node_ip.value'))

# Initializes the NGINX server
nginx-init: nginx-get-ip
	@ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$(IP_ADDR_NGINX) \
		'sudo bash -s' < ./scripts/init_nginx.sh

# Configures the NGINX server and SSL
nginx-config:
	@$(eval CF_EMAIL := $(shell op item get cloudflare_$(CF_DOMAIN) --vault $(OP_VAULT) --fields label=email --reveal))

	@ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		ubuntu@$(CF_DOMAIN) 'sudo bash -s "$(CF_DOMAIN)" "$(CF_EMAIL)"' < ./scripts/config_nginx.sh

# Updates the html files
nginx-update-html:
	@$(eval CF_DOMAIN := $(shell op item get cloudflare_$(CF_DOMAIN) --vault $(OP_VAULT) --fields label=url))

	@ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$(CF_DOMAIN) \
		'mkdir -p /home/ubuntu/temp/html'

	@scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		./html/ ubuntu@$(CF_DOMAIN):/home/ubuntu/temp/

	@ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$(CF_DOMAIN) \
		'sudo rm -rf /var/www/$(CF_DOMAIN)/html && sudo mv /home/ubuntu/temp/html /var/www/$(CF_DOMAIN) && rm -rf /home/ubuntu/temp'

# Allow the k3s server to receive requests via the public IP, delete the existing kubeconfig file and update 1Password with the new config file.
# @$(MAKE) --no-print-directory store
# store: k3s-master-get-ip
# 	@op document delete kubeconfig --vault Dev 2>/dev/null || true

# 	@ssh ubuntu@$(IP_ADDR_K3S_MASTER) 'sudo cat /etc/rancher/k3s/k3s.yaml' | \
# 		sed 's/server: https:\/\/127.0.0.1:6443/server: https:\/\/$(IP_ADDR_K3S_MASTER):6443/' | \
# 			op document create --file-name config.yaml --title kubeconfig --vault Dev -