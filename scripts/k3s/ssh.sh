#!/bin/bash

ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ubuntu@$(terraform  -chdir=infra output --json | jq -r '.master_node_ip.value')