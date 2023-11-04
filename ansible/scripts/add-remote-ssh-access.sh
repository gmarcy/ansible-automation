#!/usr/bin/env bash

set -e

key_name=$1
remote_user=$2
remote_host=$3
become_user=$4

ansible-playbook -vvv --user ${remote_user} -i inventory/homelab-facts.yml books/add-remote-ssh-access.yml -e remote_hosts_spec='[{"host":"'${remote_host}'","become_user":"'${become_user}'"}]' -e authorized_key_name=${key_name}
