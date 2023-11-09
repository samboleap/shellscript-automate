#!/bin/bash

#remote to  server
read -p "Enter the server address: " server_address
read -p "Enter the server username: " server_username
read -p "Enter the server ssh key path: " server_ssh_path

#SSH command 
ssh_command="ssh -i $server_ssh_path $server_username@$server_address"

# Connect to the server
$ssh_command