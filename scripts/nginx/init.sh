#!/bin/bash

apt update
apt upgrade -y
apt install -y nginx php-fpm
snap install core
snap refresh core
snap install --classic certbot

# Uncomment the server_names_hash_bucket_size directive
sed -i 's/# server_names_hash_bucket_size/server_names_hash_bucket_size/' /etc/nginx/nginx.conf

ln -sf /snap/bin/certbot /usr/bin/certbot

ufw allow 'Nginx Full'
ufw delete allow 'Nginx HTTP'