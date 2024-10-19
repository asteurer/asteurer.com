#!/bin/bash

docker build ./db_client -t ghcr.io/asteurer/asteurer.com-db-client
docker build ./meme_manager -t ghcr.io/asteurer/asteurer.com-meme-manager

docker login ghcr.io

docker push ghcr.io/asteurer/asteurer.com-db-client
docker push ghcr.io/asteurer/asteurer.com-meme-manager

