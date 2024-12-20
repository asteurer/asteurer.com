.PHONY: build
build:
	@docker build . -t hugo

.PHONY: run
run: rm
	@docker run -dt -p 1313:1313 --name hugo hugo

.PHONY: rm
rm:
	@docker rm hugo

.PHONY: stop
stop:
	@docker stop hugo

.PHONY: exec
exec:
	@docker exec -it hugo /bin/sh


# Copy work that was done locally to the running docker container and reset the npm install
.PHONY: copy-to
copy-to:
	@docker cp ./app/. hugo:/app/

# Copy the built files locally
.PHONY: copy-from
copy-from:
	@docker cp hugo:/app/. ./app/

