#!/bin/bash

domain=$1
aws_region=$2
op_vault=$3
email=$(op item get cloudflare_$domain --vault $op_vault --fields label=email --reveal)


# Create static site files directory
mkdir -p /var/www/$domain/html
# chown -R $USER:$USER /var/www/$domain/html
chown -R www-data:www-data /var/www/$domain/html
chmod -R 755 /var/www/$domain

# Create NGINX configuration file for site
cat <<EOF > /etc/nginx/sites-available/$domain
server {
    listen 80;
    listen [::]:80;

    root /var/www/$domain/html;

    # Default to these when attempting to serve content
    index index.html index.php;

    server_name $domain www.$domain;

    location /resume {
         proxy_pass https://s3.$aws_region.amazonaws.com/$domain-prod/resume.pdf;
    }

    # /memes will be handled by general fallback

    # Handle URLs like /memes/1
    location ~ ^/memes/(\d+)$ {
        rewrite ^/memes/(\d+)$ /memes/index.php?id=\$1 last;
    }

    # PHP scripts
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    # General fallback
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/

OUTPUT=$(nginx -t 2>&1)
if [ $? -ne 0 ]; then
    echo "Nginx configuration test failed. Not restarting Nginx."
    echo "$OUTPUT"
    exit 1
else
    systemctl restart nginx
fi

sudo certbot --nginx --agree-tos -n -d $domain -d www.$domain -m $email
sudo systemctl status snap.certbot.renew.service

# Command below is optional, but saving just in case...
# sudo certbot renew --dry-run