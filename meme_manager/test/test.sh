#!/bin/bash

# Exporting for Terraform
export AWS_ACCESS_KEY_ID=$(op item get aws_asteurer_temp --fields label=access_key --reveal)
export AWS_SECRET_ACCESS_KEY=$(op item get aws_asteurer_temp --fields label=secret_access_key --reveal)
export AWS_SESSION_TOKEN=$(op item get aws_asteurer_temp --fields label=session_token --reveal)

region=us-west-2
bucket_name=tg-bot-test

terraform init
terraform apply \
  --var=aws_region=$region \
  --var=bucket_name=$bucket_name \
  --auto-approve

sleep 15

docker system prune -f
docker build ../ -t asteurer.com-meme-manager
docker build ../../db_client -t asteurer.com-db-client

cat <<EOF | docker compose -f - up -d
services:
  postgres:
    image: postgres
    container_name: postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
    volumes:
      - ./database:/docker-entrypoint-initdb.d
    ports:
      - 5432
    networks:
      - db-network
  db-client:
    image: asteurer.com-db-client
    container_name: db-client
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
    container_name: meme-manager
    environment:
      - AWS_ACCESS_KEY=$AWS_ACCESS_KEY_ID
      - AWS_SECRET_KEY=$AWS_SECRET_ACCESS_KEY
      - AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN
      - AWS_S3_REGION=$region
      - AWS_S3_BUCKET=$bucket_name
      - TG_BOT_TOKEN=$(op item get asteurer.com_telegram_bot --fields label=credential --reveal)
      - DB_CLIENT_URL=http://db-client:8080/meme
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


# Uncomment the following to remove the testing environment
# docker compose down

# terraform destroy \
#   --var=aws_region=$region \
#   --var=bucket_name=$bucket_name \
#   --auto-approve