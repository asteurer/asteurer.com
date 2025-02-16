#!/bin/bash

# validate_env ensures that the passed string matches a non-empty environment variable
validate_env() {
    # Take the string value, and see if it matches an env var key,
    # then see if the corresponding value is empty
    if [ -z "${!1}" ]; then
        echo "ERROR: Could not detect a value for env var '$1'"
        exit 1
    fi
}

validate_env "PG_DATABASE"
validate_env "PG_USER"
validate_env "PG_PASSWORD"
validate_env "AWS_ACCESS_KEY"
validate_env "AWS_SECRET_KEY"
validate_env "AWS_S3_REGION"
validate_env "AWS_S3_BUCKET"
validate_env "TG_BOT_TOKEN"

#-----------------------------------
# Initialize the working directory
#-----------------------------------
work_dir=~/docker
mkdir -p $work_dir

#-----------------------------------
# Create the SQL schema
#-----------------------------------
cat << EOF > $work_dir/init.sql
CREATE TABLE memes (
    id SERIAL PRIMARY KEY,
    url TEXT NOT NULL UNIQUE
);
EOF

#-----------------------------------
# Create the compose.yaml file
#-----------------------------------
cat << EOF > $work_dir/compose.yaml
name: asteurer.com
services:
  # nginx:
    # image: nginx:1.27
  # front_end:
    # image: ghcr.io/asteurer/asteurer.com-front-end
  meme-manager:
    image: ghcr.io/asteurer/asteurer.com-meme-manager
    environment:
      - AWS_ACCESS_KEY=$AWS_ACCESS_KEY
      - AWS_SECRET_KEY=$AWS_SECRET_KEY
      - AWS_S3_REGION=$AWS_S3_REGION
      - AWS_S3_BUCKET=$AWS_S3_BUCKET
      - TG_BOT_TOKEN=$TG_BOT_TOKEN
      - DB_CLIENT_URL=http://db-client:8080
  db-client:
    image: ghcr.io/asteurer/asteurer.com-db-client
    environment:
      - POSTGRES_HOST=db
      - POSTGRES_PORT=5432
      - POSTGRES_DATABASE=$PG_DATABASE
      - POSTGRES_USER=$PG_USER
      - POSTGRES_PASSWORD=$PG_PASSWORD
    depends_on:
        - db
  db:
    image: postgres:17.3-alpine3.21
    environment:
      - POSTGRES_PASSWORD=$PG_PASSWORD
      - POSTGRES_USER=$PG_USER
    volumes:
        - ./init.sql:/docker-entrypoint-initdb.d/init.sql
        - postgres_data:/var/lib/postgresql/data

volumes:
    postgres_data:
EOF

# -----------------------------------
# Start the app stack
# -----------------------------------
sudo docker compose -f $work_dir/compose.yaml up -d