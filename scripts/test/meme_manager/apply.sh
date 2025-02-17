#!/bin/bash

sudo docker stop $(sudo docker ps | awk '/website-test/ {print $1}') > /dev/null 2>&1

# Exporting for Terraform
export AWS_ACCESS_KEY_ID=$(op item get aws_asteurer_temp --fields label=access_key --reveal)
export AWS_SECRET_ACCESS_KEY=$(op item get aws_asteurer_temp --fields label=secret_access_key --reveal)
export AWS_SESSION_TOKEN=$(op item get aws_asteurer_temp --fields label=session_token --reveal)

region=us-west-2
bucket_name=asteurer.com-dev
script_dir=scripts/test/meme_manager

terraform -chdir=$script_dir init

terraform -chdir=$script_dir apply \
  --var=aws_region=$region \
  --var=bucket_name=$bucket_name \
  --auto-approve

sudo docker rm -f asteurer.com-meme-manager
sudo docker build ./meme_manager -t asteurer.com-meme-manager
sudo docker build ./db_client -t asteurer.com-db-client

cat <<EOF | sudo docker compose -f - up -d
services:
  postgres:
    image: postgres
    container_name: website-test-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
    volumes:
      - ./$script_dir/database:/docker-entrypoint-initdb.d
    ports:
      - 5432
    networks:
      - db-network
  db-client:
    image: asteurer.com-db-client
    container_name: website-test-db-client
    environment:
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DATABASE=postgres
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    ports:
      - 3000:8080
      - 8080
    depends_on:
      - postgres
    networks:
      - db-network
  meme-manager:
    image: asteurer.com-meme-manager
    container_name: website-test-meme-manager
    environment:
      - AWS_ACCESS_KEY=$(terraform -chdir=$script_dir output -json | jq -r .access_key_id.value)
      - AWS_SECRET_KEY=$(terraform -chdir=$script_dir output -json | jq -r .secret_access_key.value)
      - AWS_S3_REGION=$region
      - AWS_S3_BUCKET=$bucket_name
      - TG_BOT_TOKEN=$(op item get tg_bot --vault asteurer.com_DEV --fields label=credential --reveal)
      - DB_CLIENT_URL=http://website-test-db-client:8080/meme
    ports:
      - "8080:8080"
    depends_on:
      - db-client
    networks:
      - db-network
networks:
  db-network:
    driver: bridge
EOF