#!/bin/sh
# Lab 1 step 2: the automation user `ansible` on every host, ad hoc, as root
# with root's SSH password. Exam task 2 is the same with another user name.
#
#   ./bootstrap.sh                               asks root's password (-k), per command
#   ./bootstrap.sh -e ansible_password=redhat    no prompt (make catch-up-lab1)
set -e
[ $# -gt 0 ] || set -- -k

ansible all -u root "$@" -m ansible.builtin.user \
    -a 'name=ansible groups=wheel append=true'
ansible all -u root "$@" -m ansible.posix.authorized_key \
    -a "user=ansible key='{{ lookup('file', '~/.ssh/id_ed25519.pub') }}'"
ansible all -u root "$@" -m ansible.builtin.copy \
    -a 'content="ansible ALL=(ALL) NOPASSWD: ALL\n" dest=/etc/sudoers.d/ansible mode=0440 validate="visudo -cf %s"'
