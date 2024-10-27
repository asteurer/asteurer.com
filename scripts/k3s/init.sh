#!/bin/bash

ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ubuntu@$(terraform  -chdir=infra output --json | jq -r '.master_node_ip.value') \
    'curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san $(curl http://checkip.amazonaws.com)" sh -'

sleep 60 # Wait for the cluster to initialize...