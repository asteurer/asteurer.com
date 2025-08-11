#!/bin/bash

script_dir=test/db_client

python3 -m venv ./venv
source ./venv/bin/activate
pip install -r ./$script_dir/requirements.txt

docker compose -f $script_dir/compose.yaml up -V -d

# Give the compose stack time to initialize...
sleep 10

pytest

# This will run, even if pytest fails
sudo docker stop $(sudo docker ps | awk '/test-db-client/ {print $1}')