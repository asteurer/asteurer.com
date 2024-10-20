#!/bin/bash

docker build ../ -t asteurer.com-db-client;
pip install -r requirements.txt;
docker compose up -d;
sleep 5;
pytest;
docker compose down;