# Lab 1 — inventory and ad-hoc tasks

**Slides:** *Session 1* (`module4_session1.md`), *Lab 1* · **~40 min**,
alone

The start of `~/m4`, the project of the whole module: a Git repo, an
`ansible.cfg`, an INI inventory, and the managed hosts brought from "root
with a password" to "user `ansible`, key, passwordless sudo" — the exam's
first task. Then the first tasks, ad hoc, run twice.

| Step | | ~ |
| --- | --- | --- |
| [step1-project](step1-project/) | project dir, Git repo, `ansible.cfg` | 5 min |
| [step2-bootstrap](step2-bootstrap/) | bootstrap user `ansible`: key, sudo | 10 min |
| [step3-inventory](step3-inventory/) | inventory: `web`, `db`, `prod` | 5 min |
| [step4-adhoc](step4-adhoc/) | install a package, create a user, start a service | 15 min |
| [step5-again](step5-again/) | run it all again, compare | 5 min |

| File | What it is |
| --- | --- |
| [`solution/`](solution/) | `~/m4` at the end of the lab: `ansible.cfg`, `inventory`, and the ad-hoc commands of steps 2 and 4 as `bootstrap.sh` and `adhoc.sh` |

**Start**: the nodes in their initial state (root, password `redhat`, no
other user), and `check` green, in your console:

```sh
cd ~/trainings_exercises/f021bis/module4
make -C lab0 reset
make -C lab0 check        # sshpass present, 3 nodes running, password login offered
```

**End state** (start of lab 2): `~/m4`, a Git repo tagged `lab1`, with
`ansible.cfg`, `inventory`, `bootstrap.sh`, `adhoc.sh`; on every node, user
`ansible` with your key and passwordless sudo, `chrony` installed and
`chronyd` running and enabled, user `devops`, `/etc/motd`;
`ansible all -m ansible.builtin.ping` green with no option. From nothing:
`make catch-up-lab1` in `module4/` (moves an existing `~/m4` aside,
bootstraps the nodes with root's password, runs `adhoc.sh`).

## What was found on a local run

The solution was run on a laptop against `lab0`'s nodes, from an
`ubuntu:24.04` container standing in for the console (its `ansible` and
`sshpass` packages, OpenSSH 9.6). Not yet in an f021bis console.

- **The console's Ansible**: ansible-core 2.16.3, with ansible.posix
  1.5.4, community.general 8.3.0, community.mysql 3.8.0 and
  community.crypto 2.17.1 bundled (Ubuntu's `ansible` 9.x package).
  `ansible.posix.authorized_key` needs nothing installed.
- **`ssh-keyscan -q` does not exist in OpenSSH 9.6** (the console's); a
  newer laptop accepts it. `lab0`'s `known-hosts` used it and recorded
  nothing: fixed. Without those keys every `-k` command fails with *Host Key
  checking is enabled and sshpass does not support this*.
- `bootstrap.sh`: 3 × `CHANGED` on the first run, all `SUCCESS` on the
  second. `/etc/sudoers.d/ansible` is `0440`, one line with its newline
  (the `\n` in `content=` inside `-a '…'` is kept as a newline).
- No interpreter warning: Rocky 9's `/usr/bin/python3` is discovered
  silently by ansible-core 2.16.
- `adhoc.sh`: the four state commands go `CHANGED` → `SUCCESS`, `command`
  and `shell` stay `CHANGED`. `dnf install chrony` took seconds.
- **chronyd**: the node image ships `/etc/sysconfig/chronyd` with
  `OPTIONS="-F 2 -x"`; the package leaves it alone and writes
  `/etc/sysconfig/chronyd.rpmnew` beside it, and `chronyd -F 2 -x` runs. Without
  `-x`, chronyd in a privileged container (`CAP_SYS_TIME`) would steer the
  server's clock, for every trainee's three nodes.
