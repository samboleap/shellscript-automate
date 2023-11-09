#!/bin/bash

# Prompt for master server details
read -p "Enter the master server username: " master_user
read -p "Enter the master server IP address: " master_server

# Generate SSH key pair on the master server if not already generated
if [ ! -f ~/.ssh/id_rsa.pub ]; then
  ssh-keygen -t rsa -b 4096 -C "ansible-master" -f ~/.ssh/id_rsa -N ""
fi

# Prompt for the number of nodes
read -p "Enter the number of node servers: " num_nodes

# Loop to prompt for node server details
node_servers=()
for ((i=1; i<=$num_nodes; i++)); do
  read -p "Enter node $i server username and IP address (format: username@ip): " server_info
  node_servers+=("$server_info")
done

# Function to copy SSH public key to a server
copy_ssh_key() {
  local username=$1
  local ip=$2
  scp -o StrictHostKeyChecking=no ~/.ssh/id_rsa.pub "$username@$ip:~/temp_key.pub"
  ssh -o StrictHostKeyChecking=no "$username@$ip" "mkdir -p ~/.ssh && cat ~/temp_key.pub >> ~/.ssh/authorized_keys && rm ~/temp_key.pub"
}

# Loop through the node servers and copy the SSH public key
for server in "${node_servers[@]}"; do
  node_username=$(echo "$server" | cut -d "@" -f1)
  node_ip=$(echo "$server" | cut -d "@" -f2)
  copy_ssh_key "$node_username" "$node_ip"
done

# Copy the SSH public key to the master server
copy_ssh_key "$master_user" "$master_server"