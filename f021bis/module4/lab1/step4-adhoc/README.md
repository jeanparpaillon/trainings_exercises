# Step 4 — install a package, create a user, start a service

**Slides:** *SSH and ad-hoc commands* · **~15 min**

Four ad-hoc commands on **all** hosts, with **no** `-u`, `-k`, `-b` and no
`-i`: `ansible.cfg` and the inventory say it all. One module each, by its
**FQCN** (`ansible.builtin.…`), found with `ansible-doc` only:

| | State wanted | Hint |
| --- | --- | --- |
| 1 | package `chrony` installed | `ansible-doc -l \| grep -i dnf` |
| 2 | service `chronyd` running **and** enabled at boot | one command, two options |
| 3 | user `devops` exists | |
| 4 | `/etc/motd` contains exactly `Managed by Ansible` and a newline | `copy` with `content=`, not `src=` |

```sh
ansible-doc -l | grep -iE 'dnf|service|user|copy'
ansible-doc -s ansible.builtin.service
```

Write a **state**, not an action: `state=present`, `state=started`, not
"install", "start". That is what makes step 5 work.

Keep the four commands in `~/m4/adhoc.sh` as you go.

## Check — on the hosts, not in the recap

```sh
ansible all -m ansible.builtin.command -a 'rpm -q chrony'
ansible all -m ansible.builtin.command -a 'systemctl is-enabled chronyd'
ansible all -m ansible.builtin.command -a 'systemctl is-active chronyd'
ansible all -m ansible.builtin.command -a 'id devops'
ssh ansible@node3 cat /etc/motd
```

```sh
git add -A && git commit -m "first ad-hoc tasks"
```

## Questions

- `chronyd` is the NTP client: what would it do to a real server's clock?
  The nodes are containers sharing the training server's kernel —
  `cat /etc/sysconfig/chronyd` on a node to see why it leaves the clock
  alone here.
- Which of the four commands needed root? How would you run **one**
  ad-hoc command *without* sudo, now that `become = true` is the default?
- `ansible.builtin.package` would also have installed `chrony`. When would
  you choose it over `ansible.builtin.dnf`?
