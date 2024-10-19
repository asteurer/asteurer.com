DOMAIN := asteurer.com
AWS_REGION := us-west-2
OP_VAULT := asteurer.com_infra

# Deploy the infrastructure
tf-apply:
	@./scripts/terraform/apply.sh "$(DOMAIN)" "$(OP_VAULT)" "$(AWS_REGION)"

# Destroy the infrastructure
tf-destroy:
	@./scripts/terraform/destroy.sh "$(DOMAIN)" "$(OP_VAULT)" "$(AWS_REGION)"

# SSH into the NGINX server
nginx-ssh:
	@ssh \
		-o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null \
		ubuntu@$(DOMAIN)

# Initializes the NGINX server
nginx-init:
	@ssh \
		-o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null \
		ubuntu@$(DOMAIN) \
		'sudo bash -s' < ./scripts/nginx/init.sh

# Configures the NGINX server
nginx-config:
	@ssh \
		-o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null \
		ubuntu@$(DOMAIN) \
		'sudo bash -s "$(DOMAIN)" "$(AWS_REGION)" "$(OP_VAULT)"' < ./scripts/nginx/config.sh

# Updates the html files on the NGINX server
nginx-update-html:
	@./scripts/nginx/update_html.sh "$(DOMAIN)"

# SSH into the K3S node
k3s-ssh:
	@./scripts/k3s/ssh.sh

# Initialize a K3S cluster configured to allow kubeconfig to work outside the server
k3s-init:
	@./scripts/k3s/init.sh

# Retrieve, alter, and store the kubeconfig file
k3s-store:
	@./scripts/k3s/kubecfg_store.sh "$(DOMAIN)"

# Install the 1Password connect server
k3s-install-op:
	@./scripts/k3s/helm_op_connect.sh

# Install the website back-end
k3s-install-backend:
	@./scripts/k3s/helm_backend.sh

# Build and push Docker images to ghcr.io
docker:
	@./scripts/docker/build_and_push.sh

# Run integration tests against the db-client
test-db-client:
	@./scripts/test/db_client/test.sh

# Set up the manual testing environment for the meme-manager
test-begin-meme-manager:
	@./scripts/test/meme_manager/apply.sh

# Destroy the manual testing environment for the meme-manager
test-end-meme-manager:
	@./scripts/test/meme_manager/destroy.sh