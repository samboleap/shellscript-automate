#!/bin/bash

ansible-playbook -i host.ini /root/shellscript-automate/ansible/installNginx/playbook.yml &&
ansible-playbook -i host.ini /root/shellscript-automate/ansible/installJava/playbook.yml &&
ansible-playbook -i host.ini /root/shellscript-automate/ansible/installDocker/playbook.yml