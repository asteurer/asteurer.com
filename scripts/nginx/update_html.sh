domain=$1

# Create a temp dir...
ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null ubuntu@$domain \
	"mkdir -p /home/ubuntu/temp/html"

# Copy the html dir to the temp dir...
scp \
    -r \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
	./html/ ubuntu@$domain:/home/ubuntu/temp/

# Remove current var/www/html dir, replace with new html dir, and remove temp dir...
ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null ubuntu@$domain \
	"sudo rm -rf /var/www/$domain/html && sudo mv /home/ubuntu/temp/html /var/www/$domain && rm -rf /home/ubuntu/temp"