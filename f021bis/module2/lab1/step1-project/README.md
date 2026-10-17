# Step 1 — the project, `ansible.cfg`, the inventory

**Slides:** Ansible recap — inventory · **~10 min**

`~/m2` is the project of the whole module: this inventory is the one
Kubespray deploys from in lab 3, so it uses **Kubespray's group names** from
the start.

## The project

```sh
mkdir ~/m2 && cd ~/m2
git init
git config user.name  >/dev/null || git config --global user.name  "<your names>"
git config user.email >/dev/null || git config --global user.email "<an email>"
```

`.gitignore`, two lines:

- `.vault_pass`
- `inventory/artifacts/` (Kubespray writes a cluster-admin kubeconfig there
  in lab 3)

## The vault password, now

`ansible.cfg` below names a vault password file. From then on, **every**
Ansible command, even `ansible-inventory`, fails if that file is missing.
Create it before the config, outside the repo, readable only by you:

```sh
(umask 077; head -c 24 /dev/urandom | base64 > ~/.vault_pass)
ls -l ~/.vault_pass                     # -rw-------
```

## `ansible.cfg`

In `~/m2`. Write it yourself; it needs:

| Setting | Section | Value | Why |
| --- | --- | --- | --- |
| `inventory` | `[defaults]` | `./inventory` | a directory: `hosts.yml` and, next to it, `group_vars/` |
| `remote_user` | `[defaults]` | `ansible` | the nodes' user, key-only, passwordless sudo |
| `roles_path` | `[defaults]` | `./roles` | |
| `vault_password_file` | `[defaults]` | `~/.vault_pass` | step 5 |
| `host_key_checking` | `[defaults]` | `False` | lab nodes are recreated with new host keys; never on real servers |
| `interpreter_python` | `[defaults]` | `auto_silent` | otherwise a warning about `/usr/bin/python3.12` on every host, every run |
| `become` | `[privilege_escalation]` | `true` | everything the role does is root's |

```sh
ansible --version          # "config file = /root/m2/ansible.cfg"? which ansible-core?
```

If `config file` is not `~/m2/ansible.cfg`, you are not in `~/m2`, or the
venv is not active.

## The inventory

`inventory/hosts.yml`, in YAML. Three hosts, each with `ansible_host` = its
fixed IP (`.11`, `.12`, `.13` of `NODE_SUBNET` in `versions.env`), and the
groups of Kubespray's sample inventory
(`~/kubespray/inventory/sample/inventory.ini` — read it):

| Group | Members |
| --- | --- |
| `kube_control_plane` | `node1` |
| `etcd` | `node1` |
| `kube_node` | `node2` |
| `k8s_cluster` | the **groups** `kube_control_plane` and `kube_node` (`children:`) |
| `spare` | `node3` |

## Check

```sh
ansible-inventory --graph
ansible-inventory --host node1
ansible all -m ansible.builtin.ping
ansible k8s_cluster --list-hosts
```

`ping` is not ICMP: it is a module, copied over SSH and run with the node's
Python, as `root` (through `become`). Green means SSH, sudo and Python all
work.

```sh
git add -A && git commit -m "project, inventory"
```

## Questions

- Why does `node3` exist but sit outside `k8s_cluster`? What would
  `hosts: all` in a playbook do with it?
- `etcd` is not under `k8s_cluster`, yet `node1` is in both. What does
  `ansible etcd:&kube_node --list-hosts` print, and when would it not be
  empty?
