#!/bin/sh
# Step 1: the automation user `ansible` on every host, ad hoc, as root with
# root's SSH password.
#
#   ./bootstrap.sh                               asks root's password (-k), per command
#   ./bootstrap.sh -e ansible_password=redhat    no prompt (make catch-up-stepN)
set -e
[ $# -gt 0 ] || set -- -k

ansible all -u root "$@" -m user \
    -a 'name=ansible groups=wheel append=true'
ansible all -u root "$@" -m authorized_key \
    -a "user=ansible key='{{ lookup('file', '~/.ssh/id_ed25519.pub') }}'"
ansible all -u root "$@" -m copy \
    -a 'content="ansible ALL=(ALL) NOPASSWD: ALL\n" dest=/etc/sudoers.d/ansible mode=0440 validate="visudo -cf %s"'
