.PHONY: tf-apply tf-show tf-plan tf-destroy tfvars \
		nginx-ssh nginx-show-ip nginx-get-ip nginx-config nginx-update-html \
		master-ssh master-get-ip master-init-k3s master-store-kubeconfig \
		master-install-op-connect master-install-meme-db docker-build docker-push



CF_DOMAIN := asteurer.com
AWS_REGION := us-west-2
OP_VAULT := asteurer.com_infra

#################################################################################
# Terraform
#################################################################################

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

#################################################################################
# NGINX Node
#################################################################################

# SSH into the EC2 instance
nginx-ssh: nginx-get-ip
	@ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$(IP_ADDR_NGINX)

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
	@ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$(CF_DOMAIN) \
		'mkdir -p /home/ubuntu/temp/html'

	@scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		./html/ ubuntu@$(CF_DOMAIN):/home/ubuntu/temp/

	@ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$(CF_DOMAIN) \
		'sudo rm -rf /var/www/$(CF_DOMAIN)/html && sudo mv /home/ubuntu/temp/html /var/www/$(CF_DOMAIN) && rm -rf /home/ubuntu/temp'

#################################################################################
# K3S Master Node
#################################################################################

master-ssh: master-get-ip
	@ssh ubuntu@$(IP_ADDR_MASTER)

master-get-ip:
	@$(eval IP_ADDR_MASTER := $(shell terraform  output --json | jq -r '.master_node_ip.value'))

master-init-k3s: master-get-ip
	@ssh ubuntu@$(IP_ADDR_MASTER) 'curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san $$(curl http://checkip.amazonaws.com)" sh -'

# @$(MAKE) --no-print-directory store
master-store-kubeconfig: master-get-ip
	@ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$(IP_ADDR_MASTER) \
		'sudo cat /etc/rancher/k3s/k3s.yaml' | \
			sed 's/server: https:\/\/127.0.0.1:6443/server: https:\/\/$(IP_ADDR_MASTER):6443/' > \
				~/.kube/$(CF_DOMAIN).config

# Configures the NGINX server and SSL
nginx-config:
	@$(eval CF_EMAIL := $(shell op item get cloudflare_$(CF_DOMAIN) --vault $(OP_VAULT) --fields label=email --reveal))

# Install the connect server and wait for it to initialize
master-install-op-connect:
	@helm repo add 1password https://1password.github.io/connect-helm-charts/
	@helm upgrade --install op-connect 1password/connect \
		--namespace 1password \
		--create-namespace \
		--set connect.credentials_base64="$$(op document get op_connect_creds --vault asteurer.com_apps | base64 -w 0)" \
		--set operator.create=true \
		--set operator.token.value="$$(op item get op_connect_token --vault asteurer.com_apps --fields label=credential --reveal)" \
		--set operator.autoRestart=true

	@sleep 120

# Install the meme-database stack
master-install-meme-db:
	@helm upgrade --install meme-db-release ./helm_charts/memes --values ./helm_charts/memes/values.yaml

#################################################################################
# Build Docker images
#################################################################################

docker-build:
	@docker build ./db_client -t ghcr.io/asteurer/asteurer.com-memes-client

docker-push:
	@docker push ghcr.io/asteurer/asteurer.com-memes-client
