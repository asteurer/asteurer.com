#!/bin/bash

read -p "Path to env file: " env_file_path
source $env_file_path

# validate_env ensures that the passed string matches a non-empty environment variable
validate_env() {
    # Take the string value, and see if it matches an env var key,
    # then see if the corresponding value is empty
    if [ -z "${!1}" ]; then
        echo "ERROR: Could not detect a value for env var '$1'"
        exit 1
    fi
}

validate_env "PG_USER"
validate_env "PG_PASSWORD"
validate_env "AWS_ACCESS_KEY"
validate_env "AWS_SECRET_KEY"
validate_env "AWS_S3_REGION"
validate_env "AWS_S3_BUCKET"
validate_env "TG_BOT_TOKEN"
validate_env "CF_TOKEN"

cat << EOF > ../../helm/values.yaml
frontEnd:
  image: ghcr.io/asteurer/asteurer.com-front-end

database:
  image: postgres:17
  secrets:
  - name: postgres-password
    value: $PG_PASSWORD
  - name: postgres-user
    value: $PG_USER

dbClient:
  image: ghcr.io/asteurer/asteurer.com-db-client

memeManager:
  image: ghcr.io/asteurer/asteurer.com-meme-manager
  secrets:
  - name: aws-access-key
    value: $AWS_ACCESS_KEY
  - name: aws-secret-key
    value: $AWS_SECRET_KEY
  - name: aws-s3-region
    value: $AWS_S3_REGION
  - name: aws-s3-bucket
    value: $AWS_S3_BUCKET
  - name: tg-bot-token
    value: $TG_BOT_TOKEN

cloudflared:
  image: cloudflare/cloudflared:2025.4.0
  token: $CF_TOKEN
EOF