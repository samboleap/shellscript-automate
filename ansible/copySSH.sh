#!/bin/bash

# Prompt for master server details
read -p "Enter the master server username: " master_user
read -p "Enter the master server IP address: " master_server

# Generate SSH key pair on the master server
ssh-keygen -t rsa -b 4096 -C "ansible-master" -f ~/.ssh/id_rsa -N ""

# Prompt for node server details
node_servers=()
while true; do
  read -p "Enter a node server username and IP address (format: username@ip), or press Enter to finish: " server_info
  if [[ -z $server_info ]]; then
    break
  fi
  node_servers+=("$server_info")
done

# Loop through the node servers and copy the SSH public key
for server in "${node_servers[@]}"; do
  ssh-copy-id -i ~/.ssh/id_rsa.pub $master_user@$master_server $server
done