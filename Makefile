server_ip := 192.168.5.172

.PHONY: init-apps
init-apps:
	@set -a; source $$(pwd)/init_apps.env; set +a; ./scripts/infra/init_apps.sh