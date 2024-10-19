#!/bin/bash

helm repo add 1password https://1password.github.io/connect-helm-charts/

helm upgrade --install op-connect 1password/connect \
    --namespace 1password \
    --create-namespace \
    --set connect.credentials_base64="$(op document get op_connect_server --vault asteurer.com_PROD | base64 -w 0)" \
    --set operator.create=true \
    --set operator.token.value="$(op item get op_connect_server --vault asteurer.com_PROD --fields label=access_token --reveal)" \
    --set operator.autoRestart=true

sleep 120 # Wait for the 1Password Connect Server to initialize...