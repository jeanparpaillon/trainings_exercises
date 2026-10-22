# Module 4 — Preparing the Red Hat Ansible certification

Exercises for module 4 of **F021bis — Kubernetes in production**: one
**4-hour session**, the six EX407 program items, one step each. The slides
are in `../../../trainings/f021bis/slides/module4.md` (the plan is the note
of its title slide) and one sub-deck per step (`module4_step1.md` …
`module4_step6.md`, `module4_wrapup.md`); each step file names the slides
it belongs to, and the slides point back with `📖 module4/README.md — Step N`.

> **Status**: steps 0–6 written (step files, solutions, `make venv`,
> `make catch-up-step1…6`) and run on a laptop (Docker 29.1.3, cgroup v2,
> 2026-10-21) from an `ubuntu:24.04` stand-in for the console, with the
> nodes **offline** — see [What was found](#what-was-found-on-a-local-run).
> Not yet in a console on the server. Items marked **(to validate)** are
> what that first console run must confirm.

| | Step | EX407 item | ~ |
| --- | --- | --- | --- |
| [step0/](step0/) | environment: venv, image, nodes, `~/m4` | — | 15 min |
| [step1/](step1/) | inventory, `ansible` user, become | 1 — inventories, groups of hosts | 40 min |
| [step2/](step2/) | first playbook: httpd | 2 — playbooks | 25 min |
| [step3/](step3/) | configure to a state: MariaDB on `db`, users | 3 — configure systems to a state | 30 min |
| [step4/](step4/) | template `index.html`, conf.d snippet, handler | 4 — templates | 30 min |
| [step5/](step5/) | role `httpd` | 5 — roles | 30 min |
| [step6/](step6/) | Vault: `/private/` behind a password | 6 — Vault | 30 min |
| [lab0/](lab0/) | managed hosts: image, up, reset | — | — |

With the three intro slides (15 min), the break (10 min) and the wrap-up
(15 min): 240 min.

Module 4 is **Ansible for its own sake, no Kubernetes**, run as a
**challenge**: no AI, documentation is `ansible-doc` and docs.ansible.com
only. The trainees already did formation-prod (Day 3) and module 2, so the
steps are short and the assessment is whether each step's checks pass. What
is new compared with module 2:

- **real SSH hosts** with a dedicated automation user and sudo, instead of
  `ansible_connection: docker`;
- **RHEL-family** managed nodes (`dnf`, `firewalld`, `systemd`);
- **the exam's generation of Ansible** (2.9, see
  [Prerequisites](#prerequisites)), short module names, `ansible-doc` as the
  only documentation.

Out of scope in 4 hours: `pre_tasks`, `serial`, precedence beyond
`group_vars` < play vars < `-e`, custom facts, collections, tags,
`import_*` / `include_*` beyond `import_playbook`, `block`/`rescue`,
`assert`, a mock exam.

## Where the labs run

In the trainee's **web console** on the f021bis dev cluster (see
[`../shared-cluster/README.md`](../shared-cluster/README.md)):

| Role | What | Name |
| --- | --- | --- |
| control node | the console itself: Ansible 2.9 from `make venv`, `git`, `ssh`, `sshpass` | — |
| managed nodes | 3 containers in the console's Docker (dind sidecar), Rocky Linux 9, `systemd` and `sshd` running | `node1`, `node2`, `node3` |

**Alone, not in pairs**: everyone needs their own hosts, and three small
containers are far lighter than a kind cluster (see [Size](#size-trainer)).

| Host | Group | Gets |
| --- | --- | --- |
| `node1`, `node2` | `web` | httpd (step 2 →), page and snippet (step 4 →), `/private/` (step 6) |
| `node3` | `db` | MariaDB (step 3 →) |
| all | — | user `ansible` (step 1), `alice`, `bob` (step 3); `webadmin` on `web` only |

## Makefile

From `module4/`, in the console:

| Target | Does |
| --- | --- |
| `make venv` | `~/.venv/m4`: Ansible 2.9 on a Python 3.8 that **uv** fetches into `~/.local` (uv itself too, checksum-verified); versions in [`versions.env`](versions.env) |
| `make image` · `up` · `down` · `reset` · `check` | `lab0/`'s targets, below |
| `make catch-up-stepN` | `~/m4` = `stepN/solution`, one commit, tag `stepN`; then the whole chain from the bootstrap with root's password (`bootstrap.sh`, then `web.yml` or `site.yml`), so it works on blank nodes too. An existing `~/m4` is moved aside to `~/m4.<date>`. Step 6's also writes `~/.vault_pass` (`m4vault`), moving a different one aside |
| `make pull-consoles` | trainer, from their machine: in every console, module 2's nodes `down`, then `venv image up` |
| `make reset-consoles` | trainer, from their machine: `make reset` in every console, in parallel, one output line per console prefixed with its name; `~/m4`, the venv and `~/.vault_pass` are not touched |

The Makefile puts `~/.venv/m4/bin` first in `PATH`, so its targets use the
venv's Ansible whether the trainee's shell has activated it or not.

## Managed hosts — `lab0/`

| Target | Does |
| --- | --- |
| `make -C lab0 image` | builds `m4-node:latest` in the console's Docker (Dockerfile in `lab0/node/`) |
| `make -C lab0 up` | network `m4` (`172.30.4.0/24`), `node1`…`node3` at **fixed IPs** `.11`–`.13`, their names in the console's `/etc/hosts`, their new host keys in `~/.ssh/known_hosts` (old ones removed) |
| `make -C lab0 reset` | `down` then `up`: the three nodes back in their **initial** state (before step 1, step 5's rebuild) |
| `make -C lab0 down` | deletes the nodes (those labelled `f021bis.module=m4` only) and the network |
| `make -C lab0 check` | ansible and sshpass in the console, image, per node: state, IP, `systemctl is-system-running`, firewalld; `node1` resolves; password login offered; dnf's baked cache present; `dl.rockylinux.org` reachable (informative) |
| `make -C lab0 pull-consoles` | see the Makefile above |

The node image (`lab0/node/`):

- `rockylinux/rockylinux:9` + `systemd`, **`systemd` as PID 1** — the steps
  start, enable and restart services. Masked: gettys, udev, logind,
  `remount-fs` and two API mounts, so that `systemctl is-system-running` says
  `running`, not `degraded`;
- `openssh-server`, `python3`, `sudo`, `firewalld` (enabled),
  `policycoreutils` installed; nothing the steps install. SELinux is
  `Disabled` in a container;
- `/etc/sysconfig/chronyd` with `-x`, should anyone install chrony: in a
  privileged container it would steer the server's clock;
- **initial state = exam state**: only `root`, password login over SSH
  (`/etc/ssh/sshd_config.d/00-m4.conf`: `PermitRootLogin yes`,
  `PasswordAuthentication yes`), root password `redhat`; no `ansible` user,
  no key, no sudo rule. Step 1 is the bootstrap;
- `machine-id` and SSH host keys are removed from the image, so each node
  makes its own at boot; `up` scans the new keys into `known_hosts` as
  `node1,172.30.4.11 …`, which `ansible -k` needs (sshpass cannot answer a
  host key prompt). Host key checking itself stays on, as on the exam;
- run as module 2 runs its nodes: `--privileged`, seccomp/apparmor
  unconfined, `--cgroupns=private --tmpfs /run --tmpfs /tmp`;
- **module 2's nodes have the same names**: `up` stops with a message if a
  `node1`…`node3` without the m4 label exists, and drops module 2's
  `/etc/hosts` block and its `~/.ssh/config` block (`Host node?`,
  `User ansible`, no host key checking), which would otherwise make a
  missing `remote_user` in step 1 go unnoticed.

**`dnf` needs no network on the nodes.** The image carries the repo
metadata and every RPM the steps install — `httpd`, `mariadb-server`,
`tree` (step 1's become drill), with their weak dependencies — in dnf's
cache (`keepcache=True`, `metadata_expire=-1` in `/etc/dnf/dnf.conf`),
because Rocky's mirrorlist sent the laptop to dead or crawling mirrors and
each node downloaded ~111 MB of metadata after every `reset`. So:

- **rebuild the image before each course** (`make pull-consoles`): the baked
  metadata points at the current Rocky 9 minor, whose packages move to the
  vault when the next minor ships;
- a package **outside that list** still downloads, from `dl.rockylinux.org`
  (set as `baseurl=` instead of the mirrorlist) — add it to the list in
  `lab0/node/Dockerfile` rather than rely on that;
- weak dependencies have to be in the cache: Ansible's `dnf` installs them
  whatever `dnf.conf` says.

Still **to validate in a console**: systemd booting in dind inside a kind
node, `ssh root@node1` and `curl http://node1` by name from the console, and
`/etc/hosts` being writable there (`up` says so if not).

## Conventions

- **One project, one repo**: `~/m4/` in the console, `git init` in step 0,
  a commit and a tag `stepN` at the end of each step. The exercises repo is
  read-only reference: solutions are copied from it, never edited in place.
- **One directory per step**: `stepN/README.md` — the steps table (the same
  as on the *Step N — goal* slide: names, order, durations), the start
  state, what to write (not the solution), the checks, the end state,
  questions, troubleshooting where useful. `stepN/solution/` is a complete
  `~/m4` at the end of that step, what `make catch-up-stepN` installs; keep
  it in sync when a step's end state changes.
- **Exam style everywhere**: a `name:` on every play and task, file names and
  paths **exactly** as the step says, `ansible-doc` rather than the web,
  short module names (2.9 has no `ansible.builtin.*`).
- **The test of a step is the second run**: every step that changes hosts
  ends with "run it again, `changed=0`" and a check *on the host* (`curl`,
  `ssh`, `ansible … -m command`), not just the recap.
- **No secret in clear in Git** from step 6 on; the vault password file is
  `~/.vault_pass` (mode 600), outside the repo.

## Prerequisites

| Tool | Where |
| --- | --- |
| Ansible 2.9.27 | `make venv` → `~/.venv/m4` |
| `curl` (venv: uv and its Python), `git`, `ssh`, `ssh-keygen` | console image |
| `sshpass` | needed by `ansible -k` (step 1) — in `f021bis-console:3`; consoles still on `:2` lack it (`make check` says so) |
| `docker` | console image (dind sidecar), for `lab0` only |
| Internet from the console | `make venv` only (GitHub for uv, PyPI, uv's Python builds) — done by `pull-consoles` the day before **(to validate from a console)** |

**Why 2.9 and not 2.7** (EX407's version): 2.7 was tried first. It runs on
the control node (from a Python 3.8 venv) but cannot manage Rocky 9 — every
module fails with `AttributeError: module 'platform' has no attribute
'dist'` (removed in Python 3.8; Rocky 9 has nothing older than 3.9). 2.9 is
the last release before collections: the same short module names and the
same `ansible-doc` as the exam's generation. It does not run on the
console's Python 3.12 either (`ImportError` at start), hence uv and a
Python 3.8 build. The pins in `versions.env` are what 2.9 needs on 3.8:
Jinja2 2.11 (3.1 dropped what its filters import), MarkupSafe 1.1, and an
older setuptools and cryptography only to silence a deprecation warning on
every command.

## What was found on a local run

Run on a laptop, 2026-10-21: `make venv` in an `ubuntu:24.04` container
standing in for the console (its `ansible` and `sshpass` packages, OpenSSH
9.6), `make reset` from the host, then each `make catch-up-stepN` followed
by a second run of its playbook, **with the nodes' default route deleted**.

- `make venv` from nothing: uv 0.12.3, CPython 3.8.20, `ansible 2.9.27`;
  no warning on `ansible --version`.
- **Ansible 2.9 does not know Rocky**: `ansible_os_family` is `Rocky`, not
  `RedHat`, and without `ansible_python_interpreter` every run warns
  *Platform linux on host node1 is using the discovered Python interpreter
  at /usr/libexec/platform-python*. `package` still picks `dnf`. Step 1
  sets the variable for `all` in `inventory.yml` — after showing the
  warning.
- Every catch-up passes and every second run is `changed=0`. From blank
  nodes, `catch-up-step6` (bootstrap + the whole `site.yml`) takes 35 s:
  `changed=12` on each web node, 3 on `node3`. Step 5 on step 4's hosts:
  `changed=0` straight away.
- Without `-b`, `package` says *This command has to be run under the root
  user.*; `-b --become-user nobody` gives `uid=65534(nobody)`;
  `-e ansible_become=false` beats `become = true` in `ansible.cfg` (step 1's
  last question).
- **`ansible_default_ipv4` is empty on a host with no default route**, and
  `{{ ansible_default_ipv4.address }}` fails the template (*'dict object'
  has no attribute 'address'*): the solution falls back on
  `ansible_all_ipv4_addresses | first`. In a console the nodes have a
  default route **(to validate)**.
- httpd with no `index.html`: Rocky's test page, with status **403**
  (`welcome.conf`). With `index.html`: 200.
- **`htpasswd` would need `passlib` on the node**, and `python3-passlib` is
  in neither BaseOS nor AppStream. Step 6 writes `.htpasswd` with `copy` and
  `password_hash('sha512', <fixed salt>)` instead; on the control node 2.9
  hashes with Python's `crypt` (no passlib in the venv either). httpd
  accepts the `$6$` hash: `/private/` → 401, with `-u m4:S3cr3t!` → 200,
  with a wrong password → 401. `-v` does not print the password
  (`no_log`).

## Size (trainer)

The node image is 730 MB (uncompressed) per console, most of it Rocky and
dnf's cache; the venv is ~220 MB per console (`~/.venv/m4` 97 MB, uv's
Python 3.8 70 MB, the `uv` binary 54 MB — measured in the stand-in). The 6 × 2 h version measured an idle
node at ~41 MiB, ~57 MiB with a web server running: three nodes are well
under 300 MiB per console; measure again with step 6's end state on the
first console run.

Before the session: roll the consoles to `f021bis-console:3` (sshpass),
then `make pull-consoles` (module 2's nodes down, venv, image and nodes in
every console), `make check` and `ansible all -i node1,node2,node3, -m ping
-u root -k` from one console to prove the path. If anyone used the nodes
since (a dry run, early birds): `make reset-consoles` just before step 1.
