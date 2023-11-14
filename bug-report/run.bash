#!/usr/bin/env bash

ansible -i inventory.yml -m debug -a var=actual_value all
ansible -i inventory.yml -m debug -a var=indirect_value all
ansible -i inventory.yml -m debug -a "var=hostvars['localhost'].actual_value" all
ansible -i inventory.yml -m debug -a "var=hostvars['localhost'].indirect_value" all
ansible -i inventory.yml -m debug -a var=hostvars all
ansible-playbook -i inventory.yml play.yml 
