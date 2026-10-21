# Step 0 — environment

**Slides:** *Rules*, *Step 0* · **~15 min**, alone

Ansible in a venv, three managed hosts, an empty project. The trainer ran
`make pull-consoles` the day before: everything below should be a check,
not a download.

## Ansible

```sh
cd ~/trainings_exercises/f021bis/module4
make venv                                    # ~/.venv/m4, Ansible 2.9
. ~/.venv/m4/bin/activate
echo '. ~/.venv/m4/bin/activate' >> ~/.bashrc   # every new terminal
ansible --version
```

`ansible --version` must say **2.9.27**, with `executable location =
/root/.venv/m4/bin/ansible`. If it says `core 2.16`, the venv is not
active: that is the console's own Ansible, from `/usr/bin`.

Why a venv: Red Hat's EX407 exam ran Ansible 2.7. 2.7 cannot manage Rocky 9
(its modules need a Python older than 3.8), so this module uses **2.9**,
the last release before collections: short module names (`copy`, `user`),
everything in one package. Neither runs on the console's Python 3.12, so
`make venv` fetches a Python 3.8 with [uv](https://docs.astral.sh/uv/)
(into `~/.local`) and builds the venv from it.

## The managed hosts

```sh
make image up        # m4-node:latest, then node1…node3
make check
```

`check` must show: `sshpass` present, three nodes `running` with
`systemd=running`, `node1` in `/etc/hosts`, *password login offered*, the
dnf cache present.

| Host | Group (step 1) |
| --- | --- |
| `node1`, `node2` | `web` |
| `node3` | `db` |

They start as exam hosts do: **root, password `redhat`**, nothing else — no
`ansible` user, no key, no sudo rule. Step 1 is that bootstrap.

```sh
ssh root@node1 hostname       # password: redhat
```

## The project

`~/m4` is the project of the whole module: one Git repo, a commit and a tag
per step.

```sh
mkdir ~/m4 && cd ~/m4 && git init
git config user.name  >/dev/null || git config --global user.name  "<your name>"
git config user.email >/dev/null || git config --global user.email "<an email>"
```

Everything from step 1 on runs from `~/m4`.

## Troubleshooting

| Message | Cause |
| --- | --- |
| `ansible --version` says `core 2.16` | the venv is not active: `. ~/.venv/m4/bin/activate` |
| `node1 exists and is not an m4 node (module 2's?)` | module 2's nodes have the same names: `make -C ../module2/lab0 down`, then `make up` |
| `sshpass MISSING` | the console is older than `f021bis-console:3`: ask the trainer |
| `make venv`: `curl` or `uv python install` fails | no Internet from the console: ask the trainer (`pull-consoles` normally did it) |

## Catch-up

Lost later on? From `module4/`, `make catch-up-stepN` puts `~/m4` and the
nodes at the end of step N (`N` = 1…6). Your `~/m4` is moved aside to
`~/m4.<date>`, never deleted.
