# Step 1 — the project, Git, `ansible.cfg`

**Slides:** *Architecture, `ansible.cfg`, inventories* · **~5 min**

`~/m4` is the project of the whole module: labs 1 → 5 build on it, one tag
per lab. Everything below runs in your console, from `~/m4`.

## The project

```sh
mkdir ~/m4 && cd ~/m4
git init
git config user.name  >/dev/null || git config --global user.name  "<your name>"
git config user.email >/dev/null || git config --global user.email "<an email>"
```

## `ansible.cfg`

Write it yourself, in `~/m4`. Three settings, two sections:

| Setting | Section | Value | Why |
| --- | --- | --- | --- |
| `inventory` | `[defaults]` | `./inventory` | one INI **file**, written in step 3 |
| `remote_user` | `[defaults]` | `ansible` | the user step 2 creates; from then on, no `-u` |
| `become` | `[privilege_escalation]` | `true` | every task of this module is root's; no `-b` |

Nothing else — no `host_key_checking = False`: `make -C lab0 up` recorded
the nodes' host keys in `~/.ssh/known_hosts`, as you would on real servers.

Don't remember a setting's name or section? No browser in the exam room:

```sh
ansible-config init --disabled | less          # every setting, commented
ansible-config list | grep -A3 '^DEFAULT_REMOTE_USER'
```

## Check

```sh
ansible --version                   # config file = /root/m4/ansible.cfg
ansible-config dump --only-changed  # exactly your three settings
```

If `config file` is anything else (`None`, `/etc/ansible/ansible.cfg`), you
are not in `~/m4`.

```sh
git add -A && git commit -m "ansible.cfg"
```

## Questions

- `chmod o+w ~/m4`, then `ansible --version` again. What does Ansible say,
  which config is in effect, and why would it refuse that file? Put the
  mode back (`chmod o-w ~/m4`).
- You also have a `~/.ansible.cfg` with `remote_user = root`. Which user
  does Ansible connect as from `~/m4`? And from `~`?
