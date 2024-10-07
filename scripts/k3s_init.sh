#!/bin/bash

# Set up a k3s cluster with a kubeconfig file that will allow for kubectl commands to be run outside host server
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san $(curl http://checkip.amazonaws.com)" sh -
