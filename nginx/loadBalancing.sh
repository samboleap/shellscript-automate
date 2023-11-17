#!/bin/bash

# Define the servers
read -p "Enter the server1 IP address: " server1
read -p "Server1 port: " port1
read -p "Enter the server2 IP address: " server2
read -p "Server2 port: " port2

# Validate input values
if [[ -z $server1 || -z $port1 || -z $server2 || -z $port2 ]]; then
    echo "Server information cannot be empty. Exiting..."
    exit 1
fi

# Prompt for domain and email information
echo "Please enter your information needed to add a domain name certificate:"
read -p "Enter the domain name of the server: " domain
read -p "Enter your email address: " email

# Validate domain and email input
if [[ -z $domain || -z $email ]]; then
    echo "Domain name and email address cannot be empty. Exiting..."
    exit 1
fi

# Prompt for the Nginx configuration file name
echo "Please enter the Nginx configuration file name:"
read nginx_dns

# Validate Nginx configuration file
nginx_conf="/etc/nginx/sites-available/$nginx_dns"
if [[ -e $nginx_conf ]]; then
    echo "The specified Nginx configuration file already exists. Please choose a different file name. Exiting..."
    exit 1
fi

# Configure the Nginx server
nginx_server="
http {
    upstream backend {
        least_conn;
        server $server1:$port1;
        server $server2:$port2;
        # Add more servers here
    }

    server {
        listen 80;
        server_name $domain;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name $domain;

        ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
}
"

echo "$nginx_server" | tee "$nginx_conf" > /dev/null

# Create a symbolic link between the sites-available and sites-enabled directories in Nginx
sudo ln -s "$nginx_conf" /etc/nginx/sites-enabled/
echo "Successfully linked the configuration file for '$nginx_dns' from sites-available to sites-enabled."

# Test running with Nginx configuration
 nginx -t
echo "Nginx configuration test successful."

# Obtain SSL certificate using Certbot
 certbot --nginx --noninteractive --email "$email" -d "$domain"

# Restart Nginx
 systemctl restart nginx