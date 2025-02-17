.PHONY: update-db-client
update-db-client:
	@./scripts/test/db_client/test.sh
	@sudo docker build --no-cache ./db_client -t ghcr.io/asteurer/asteurer.com-db-client \
		&& sudo docker login ghcr.io \
		&& sudo docker push ghcr.io/asteurer/asteurer.com-db-client

.PHONY: update-front-end
update-front-end:
	@sudo docker build --no-cache ./front_end -t ghcr.io/asteurer/asteurer.com-front-end \
		&& sudo docker login ghcr.io \
		&& sudo docker push ghcr.io/asteurer/asteurer.com-front-end


.PHONY: update-meme-manager
update-meme-manager:
	@sudo docker build --no-cache ./meme_manager -t ghcr.io/asteurer/asteurer.com-meme-manager \
		&& sudo docker login ghcr.io \
		&& sudo docker push ghcr.io/asteurer/asteurer.com-meme-manager