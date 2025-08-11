.PHONY: build-front-end
build-front-end:
	docker build ./front_end -t ghcr.io/asteurer/asteurer.com-front-end

.PHONY: build-db-client
build-db-client:
	docker build ./db_client -t ghcr.io/asteurer/asteurer.com-db-client

.PHONY: build-meme-manager
build-meme-manager:
	docker build ./meme_manager -t ghcr.io/asteurer/asteurer.com-meme-manager

# Run automated tests against the db-client
.PHONY: test-db-client
test-db-client: build-db-client
	./test/db_client/script.sh

# Spin up all (except the meme-manager) components of the site
.PHONY: test-front-end
test-front-end: build-front-end build-db-client
	./test/front_end/script.sh