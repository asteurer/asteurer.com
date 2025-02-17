#!/bin/bash

script_dir=scripts/test/db_client

python3 -m venv ./venv
source ./venv/bin/activate
pip install -r ./$script_dir/requirements.txt

sudo docker system prune -f
sudo docker build ./db_client -t asteurer.com-db-client

cat <<EOF | sudo docker compose -f - up -d
services:
  postgres:
    image: postgres
    container_name: test-db-client-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
    volumes:
      - ./$script_dir/database:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"
    networks:
      - test_network
  db-client:
    image: asteurer.com-db-client
    container_name: test-db-client-client
    environment:
      - POSTGRES_HOST=test-db-client-postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DATABASE=postgres
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    networks:
      - test_network
networks:
  test_network:
    driver: bridge

EOF

# Give the compose stack time to initialize...
sleep 10

pytest

# This will run, even if pytest fails
sudo docker stop $(sudo docker ps | awk '/test-db-client/ {print $1}')