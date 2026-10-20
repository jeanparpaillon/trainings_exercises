# Step 4 — open the port, start and enable the service

**Slides:** *Lab 2* · **~5 min**

The nodes run **firewalld**, which blocks HTTP:

```sh
ansible web -m ansible.builtin.command -a 'firewall-cmd --list-services'
```

Add two tasks:

1. the firewalld **service** `http` enabled, both **permanently** (survives
   a reload or a reboot) and **now** — two options of one module, from the
   `ansible.posix` collection: `ansible-doc ansible.posix.firewalld`;
2. `nginx` started **and** enabled at boot.

## Check — from the console

```sh
ansible-playbook web.yml
curl http://node1                 # Hello from node1
curl http://node2                 # Hello from node2
curl -sI http://node1 | grep X-Managed-By
ansible web -m ansible.builtin.command -a 'systemctl is-enabled nginx'
git add -A && git commit -m "web.yml: firewall, service"
```

## Questions

- `permanent: true` without `immediate: true`: what would `curl` do right
  after the run, and after `firewall-cmd --reload`?
- `curl http://node3`: what happens, and why is that what we want?
