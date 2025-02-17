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

#-----------------------------------
# Install Docker
#-----------------------------------
sudo dnf -y install dnf-plugins-core
sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker

#-----------------------------------
# Run cloudflared
#-----------------------------------
validate_env "CF_TOKEN"
sudo docker run -d cloudflare/cloudflared:latest tunnel --no-autoupdate run --token $CF_TOKEN