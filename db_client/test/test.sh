#!/bin/bash

python3 -m venv ../../venv
source ../../venv/bin/activate
pip install -r requirements.txt

docker build ../ -t asteurer.com-db-client
docker compose up -d

sleep 2

pytest

docker compose down