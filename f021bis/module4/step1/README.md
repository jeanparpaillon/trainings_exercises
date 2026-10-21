# Step 1 — inventory, `ansible` user, become

**Slides:** *Step 1* · **~40 min** (10 theory, 30 exercise), alone ·
EX407: *use Ansible inventories to define groups of hosts*

From "root with a password" to "user `ansible`, key, passwordless sudo" —
the exam's classic first task — with a project config and an inventory in
groups. Then **become**: the user Ansible connects as is not the user tasks
run as.

| | What | ~ |
| --- | --- | --- |
| 1 | `ansible.cfg`: inventory | 3 min |
| 2 | `inventory.yml`: `web`, `db` | 5 min |
| 3 | bootstrap `ansible` (`bootstrap.sh`) | 10 min |
| 4 | `remote_user`, become drill, `become = true` | 8 min |
| 5 | checks, commit, tag `step1` | 4 min |

**Start**: step 0 — the venv active, the nodes in their initial state
(`make reset` if in doubt), `~/m4` an empty repo. Everything below runs from
`~/m4`.

## 1 — `ansible.cfg`

One setting for now, in `[defaults]`: `inventory = ./inventory.yml`.

```sh
ansible --version                    # config file = /root/m4/ansible.cfg
ansible-config dump --only-changed   # DEFAULT_HOST_LIST, and nothing else
```

If `config file` is anything else (`None`, `/etc/ansible/ansible.cfg`), you
are not in `~/m4`. No browser in the exam room: `ansible-config list` shows
every setting, its section and its environment variable.

No `host_key_checking = False`: `make up` recorded the nodes' host keys in
`~/.ssh/known_hosts`, as you would on real servers.

## 2 — `inventory.yml`

In **YAML**, write it yourself:

| Group | Members |
| --- | --- |
| `web` | `node1`, `node2` |
| `db` | `node3` |

No `ansible_host:` — the names resolve through `/etc/hosts`.

```sh
ansible-inventory --graph
ansible web --list-hosts                       # node1, node2
ansible all -u root -k -m ping                 # password: redhat
```

The `ping` works, but with a **warning** per host: read it. Ansible 2.9
looks for a Python on the node, and does not know Rocky Linux well enough
to pick it silently. Tell it which one, for every host: the variable
`ansible_python_interpreter`, value `/usr/bin/python3`, in `vars:` of the
group `all` in `inventory.yml`. The `ping` again: no warning.

## 3 — bootstrap the user `ansible`

A key first:

```sh
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
```

Then three ad-hoc commands, on `all`, as root with root's password
(`-u root -k`):

1. user `ansible`, in the supplementary group `wheel` (without removing it
   from any other);
2. your **public** key in its `authorized_keys`;
3. `/etc/sudoers.d/ansible`: `ansible` may run anything as anyone, without
   a password. A broken sudoers file locks sudo for **everyone**: have the
   module check the file with `visudo -cf %s` **before** putting it in
   place, and give it mode `0440`.

Find the modules and their options yourself:

```sh
ansible-doc -l | grep -iE 'user|authorized'
ansible-doc -s user              # a task skeleton
ansible-doc authorized_key       # the full page, with EXAMPLES
ansible-doc copy                 # content=, validate=
```

For the key, read the file on the **control node** with a lookup:
`"{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"`. Mind the quoting: the
whole `-a` in double quotes, the lookup's arguments in single.

Keep the three commands in `~/m4/bootstrap.sh` (`chmod +x`): step 5 resets
the nodes and runs it again, and so do the catch-up targets.

```sh
ssh ansible@node1 'id; sudo -n true && echo sudo ok'   # no password asked
./bootstrap.sh                                         # again: nothing changed
```

## 4 — connect as `ansible`, then become

In `ansible.cfg`, `[defaults]`: `remote_user = ansible`. From now on, no
`-u`, no `-k`. Then, **before** going further, the drill:

```sh
ansible all -m ping                            # as ansible, with the key
ansible all -m command -a id                   # uid=1000(ansible)
ansible all -m package -a name=tree            # fails: read the message
ansible all -b -m package -a name=tree         # -b: become root
ansible all -b -m command -a id                # uid=0(root)
ansible all -b --become-user nobody -m command -a id
```

Without `-b`, the package module answers *This command has to be run under
the root user.* — you are `ansible`, and `ansible` is not root.

In a playbook, `become` is a keyword of the play **or** of one task.
Write `become.yml`, one play on `node1`, `become: true` on the play, two
`command: id` tasks with `register:` and `debug:` — the second with
`become_user: nobody`. Run it: who is each task?

Every task of this module needs root: in `ansible.cfg`, section
`[privilege_escalation]`, `become = true`. Then
`ansible all -m command -a id` says root, with no `-b`.

## 5 — check, commit

```sh
ansible all -m ping                     # green, no -u, no -k, no -b
ansible all -m command -a id            # uid=0(root)
ansible-inventory --graph
ssh ansible@node2 true                  # key only
git add -A && git commit -m "step 1" && git tag step1
```

End state (start of step 2): `~/m4` tagged `step1`, with `ansible.cfg`,
`inventory.yml`, `bootstrap.sh`; on every node, user `ansible` with your key
and passwordless sudo. From nothing: `make catch-up-step1` in `module4/`.

## Questions

- `chmod o+w ~/m4`, then `ansible --version` again. Which config is in
  effect, and why would Ansible refuse that file? (`chmod o-w ~/m4`.)
- `wheel` on Rocky already grants sudo (`%wheel ALL=(ALL) ALL`). Why is it
  not enough for Ansible?
- `become = true` is now the default. How do you run **one** ad-hoc command
  as `ansible`, not root? (`ansible-doc -t keyword` does not exist in 2.9:
  think of the variable behind `-b`.)

## Troubleshooting

| Message | Cause |
| --- | --- |
| `to use the 'ssh' connection type with passwords, you must install the sshpass program` | no `sshpass` in the console (`make check`): ask the trainer |
| `Using a SSH password instead of a key is not possible because Host Key checking is enabled` | the node's host key is not in `~/.ssh/known_hosts` (sshpass cannot answer the prompt): `make -C ~/trainings_exercises/f021bis/module4/lab0 known-hosts` |
| `Permission denied (publickey,…)` on `ssh ansible@node1` | the key is not in `/home/ansible/.ssh/authorized_keys`, or it is the wrong one: `ansible node1 -u root -k -m command -a 'cat /home/ansible/.ssh/authorized_keys'` |
| `sudo: a password is required` / `Missing sudo password` | the sudoers file is missing or not applied: `ansible node1 -u root -k -m command -a 'visudo -c'` |
| a warning about the *discovered Python interpreter* on every run | `ansible_python_interpreter` not set for `all` (sub-step 2) |
