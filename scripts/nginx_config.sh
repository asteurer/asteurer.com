#!/bin/bash

CF_DOMAIN=$1
EMAIL=$2

# Create static site files directory
mkdir -p /var/www/$CF_DOMAIN/html
# chown -R $USER:$USER /var/www/$CF_DOMAIN/html
chown -R www-data:www-data /var/www/$CF_DOMAIN/html
chmod -R 755 /var/www/$CF_DOMAIN

# Create NGINX configuration file for site
cat <<EOF > /etc/nginx/sites-available/$CF_DOMAIN
server {
    listen 80;
    listen [::]:80;

    root /var/www/$CF_DOMAIN/html;

    # Default to these when attempting to serve content
    index index.html index.php;

    server_name $CF_DOMAIN www.$CF_DOMAIN;

    location /memes-api/ {
        proxy_pass http://10.0.0.4:30080/;
        proxy_set_header Authorization $http_authorization;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

	    # Increase the default payload limit from 1M
        client_max_body_size 5M;
    }

    # Handle URLs like /memes/1
    location ~ ^/memes/(\d+)$ {
        rewrite ^/memes/(\d+)$ /memes/index.php?id=$1 last;
    }

    # PHP scripts
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    # General fallback
    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

ln -sf /etc/nginx/sites-available/$CF_DOMAIN /etc/nginx/sites-enabled/

OUTPUT=$(nginx -t 2>&1)
if [ $? -ne 0 ]; then
    echo "Nginx configuration test failed. Not restarting Nginx."
    echo "$OUTPUT"
    exit 1
else
    systemctl restart nginx
fi

sudo certbot --nginx --agree-tos -n -d $CF_DOMAIN -d www.$CF_DOMAIN -m $EMAIL
sudo systemctl status snap.certbot.renew.service
sudo certbot renew --dry-run