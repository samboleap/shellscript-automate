#!/bin/bash

#Jenkins Authentication 
username="master-jenkins"
token="115cde8cb44bc1dbf8dff90a9985d34b76"
jenkins_url="http://34.121.191.11:8080"

#Create trigger build jobs for Jenkins
read -p "Please enter your Jenkins job name: " jenkins_job
echo "Your Jenkins trigger job name is $jenkins_job"

# Prompt the user for parameter values

echo "Please choose 'yes' for 'true' or 'no' for 'false' for dockerBuild:"
read -p "yes or no: " input

if [ "$input" = "yes" ]; then
    dockerBuild=true
elif [ "$input" = "no" ]; then
    dockerBuild=false
else
    echo "Invalid with input! Please choose 'yes' for 'true' or 'no' for 'false' only!"
    exit 1
fi

echo "============================================================================"

echo "Please choose 'yes' for 'true' or 'no' for 'false' for deployDocker:"
read -p "yes or no: " input

if [ "$input" = "yes" ]; then
    deployDocker=true
elif [ "$input" = "no" ]; then
    deployDocker=false
else
    echo "Invalid with input! Please choose 'yes' for 'true' or 'no' for 'false' only!"
    exit 1
fi

echo "============================================================================"

echo "Choose a branch: 1. main 2. master"
echo "1. Main"
echo "2. Master"
read -p "Please enter your choice (1 or 2): " branch

if [ "$branch" = "1" ]; then
    choice="main"
elif [ "$branch" = "2" ]; then
    choice="master"
else
    echo "Invalid with your choice! Please enter 1 for main or 2 for master!"
    exit 1
fi

echo "You has selected branch: $choice"

echo "============================================================================"

while true; do
    read -p "Please input your registry name (e.g., registry/.... or nexus/registry...): " registryDocker
    if [ -n "$registryDocker" ]; then
        break
    else
        echo "Can not leave without input! Please input to continue....."
    fi
done

echo "Your Registry Name is: $registryDocker"

echo "============================================================================"

while true; do
    read -p "Please input your image name (e.g., reactjs or springboot): " buildcontainerNameBackEnd
    if [ -n "$buildcontainerNameBackEnd" ]; then
        break
    else
        echo "Can not leave without input! Please input to continue....."
    fi
done

echo "Your Image Name is: $buildcontainerNameBackEnd"

echo "============================================================================"

while true; do
    read -p "Please input your Docker tag (e.g., v1 , 1.1.0 or default:latest): " dockerTag
    if [ -n "$dockerTag" ]; then
        break
    else
        echo "Can not leave without input! Please input to continue....."
    fi
done

echo "You Docker Tag is: $dockerTag"

echo "============================================================================"

while true; do
    read -p "Please input your Container Name for specific Docker: " containerNameBackEnd
    if [ -n "$containerNameBackEnd" ]; then
        break
    else
        echo "Can not leave without input! Please input to continue....."
    fi
done

echo "Your Container Name is: $containerNameBackEnd"

echo "============================================================================"

while true; do
    read -p "Please input your repoUrl (e.g., https://gitlab.com/myspring/maven): " repoUrl
    if [ -n "$repoUrl" ]; then
        break
    else
        echo "Can not leave without input! Please input to continue....."
    fi
done

echo "Your Repository URL is: $repoUrl"

echo "============================================================================"

# Define the servers
read -p "Enter the server1 IP address: " server1
read -p "Enter the server2 IP address: " server2

# Validate input values
if [[ -z $server1 || -z $server2  ]]; then
    echo "Server information cannot be empty. Exiting..."
    exit 1
fi

echo "============================================================================"

# Prompt for domain and email information
echo "Please enter your information needed to add a domain name certificate:"
read -p "Enter the domain name of the server: " domain
read -p "Enter your email address: " email

# Validate domain and email input
if [[ -z $domain || -z $email ]]; then
    echo "Domain name and email address cannot be empty. Exiting..."
    exit 1
fi

echo "============================================================================"

# Prompt for the Nginx configuration file name
echo "Please enter the Nginx configuration file name:"
read nginx_dns

# Validate Nginx configuration file
nginx_conf="/etc/nginx/sites-available/$nginx_dns"
if [[ -e $nginx_conf ]]; then
    echo "The specified Nginx configuration file already exists. Please choose a different file name. Exiting..."
    exit 1
fi

# Trigger the Jenkins job with user-defined environment variables

java -jar jenkins-cli.jar -auth $username:$token -s $jenkins_url -webSocket build -v \
    -p dockerBuild=$dockerBuild \
    -p deployDocker=$deployDocker \
    -p choice=$choice \
    -p registryDocker="$registryDocker" \
    -p buildcontainerNameBackEnd="$buildcontainerNameBackEnd" \
    -p containerNameBackEnd="$containerNameBackEnd" \
    -p dockerTag="$dockerTag" \
    -p repoUrl="$repoUrl" \
    $jenkins_job

# Function to check if a Docker container is running
is_container_running() {
    local containerNameBackEnd=$1
    local status=$(docker inspect -f '{{.State.Status}}' "$containerNameBackEnd" 2>/dev/null)
    
    if [[ "$status" == "running" ]]; then
        echo "Container '$containerNameBackEnd' is running."
        return 0
    else
        echo "Container '$containerNameBackEnd' is not running."
        return 1
    fi
}

# Usage container is running
is_container_running "$containerNameBackEnd"

# Function to get the mapped port of a Docker container
containerPort=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "3000/tcp") 0).HostPort}}' "$containerNameBackEnd")


# Configure the Nginx server
upstream_servers=""

upstream_servers+="server $server1:$containerPort;"
upstream_servers+="server $server2:$containerPort;"

nginx_server="
http {
    upstream backend {
        least_conn;
        $upstream_servers
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

echo "$nginx_server" |  tee "$nginx_conf" > /dev/null

# Create a symbolic link between the sites-available and sites-enabled directories in Nginx
 ln -s "$nginx_conf" /etc/nginx/sites-enabled/
echo "Successfully linked the configuration file for '$nginx_dns' from sites-available to sites-enabled."

# Test running with Nginx configuration
 nginx -t
echo "Nginx configuration test successful."

# Obtain SSL certificate using Certbot
 certbot --nginx --noninteractive --email "$email" -d "$domain"

# Restart Nginx
 systemctl restart nginx