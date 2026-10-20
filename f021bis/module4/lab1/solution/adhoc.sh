#!/bin/sh
# Lab 1 step 4: the first tasks, ad hoc, as `ansible` with sudo — no -u, -k
# or -b: ansible.cfg says it all. Step 5 runs this file twice.
set -e

ansible all -m ansible.builtin.dnf -a 'name=chrony state=present'
ansible all -m ansible.builtin.service -a 'name=chronyd state=started enabled=true'
ansible all -m ansible.builtin.user -a 'name=devops'
ansible all -m ansible.builtin.copy -a 'content="Managed by Ansible\n" dest=/etc/motd'

# Step 5: never green.
ansible all -m ansible.builtin.command -a 'uptime'
ansible all -m ansible.builtin.shell -a 'ss -tlnp | grep :22'
