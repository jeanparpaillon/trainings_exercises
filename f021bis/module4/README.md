# Module 4 — Preparing the Red Hat Ansible certification

Exercises for module 4 of **F021bis — Kubernetes in production**. The slides
are in `../../../trainings/f021bis/slides/module4.md`, one sub-deck per session
(`module4_session1.md` … `module4_session6.md`); every lab here names the
slides it belongs to, and the slides point back with
`📖 module4/README.md — Lab N`.

> **Status: specification**, except `lab0/` and labs 1–2 (step files,
> solutions, `make catch-up-lab1/2`), which are written and were run on a
> laptop (Docker 29.1.3, cgroup v2, 2026-10-20; console stood in for by
> `ubuntu:24.04` with its `ansible` package) — not yet in a console on the
> server. Labs 3–5 and `exam/` are not written yet. Items marked
> **(to validate)** are assumptions to confirm on the first dry run.

| | Lab | Session | Guided |
| --- | --- | --- | --- |
| [lab1/](lab1/) | inventory, `ansible.cfg`, bootstrap user, ad-hoc tasks | 1 | yes |
| [lab2/](lab2/) | a web service, idempotent: playbook, `loop`, handlers | 2 | yes |
| [lab3/](lab3/) | one template, two environments: variables, Jinja2, custom facts | 3 | yes |
| [lab4/](lab4/) | split the project into roles, collections | 4 | **no** — target and checks only |
| [lab5/](lab5/) | integrated deployment: Vault, `assert`, `block`/`rescue`, verification | 5 | yes |
| [exam/](exam/) | mock exam: 65 min, graded by script on the hosts | 6 | **no** |
| [lab0/](lab0/) | managed hosts, once before session 1, and their reset | — | — |

Module 4 is **Ansible for its own sake**, aimed at the certification. The
trainees already did formation-prod (Day 3: inventories, `group_vars`,
playbooks, roles, handlers, idempotence, Galaxy, Molecule) and module 2, so no
lab re-teaches those; what is new is what the exam assumes:

- **real SSH hosts** with a dedicated automation user and sudo, instead of
  `ansible_connection: docker`;
- **RHEL-family** managed nodes (`dnf`, `firewalld`, SELinux, `systemd`);
- **FQCN** modules, `ansible-doc` as the only documentation;
- **unguided work under the clock**, graded on the final state of the hosts.

Labs 1 → 5 build **one project**, in the trainee's own Git repo: each lab
starts from the previous one's end state. Lab 4 and the mock exam are the two
unguided checkpoints of the assessment (see the slides, session 4 and
session 6).

## Where the labs run

In the trainee's **web console** on the f021bis dev cluster (see
[`../shared-cluster/README.md`](../shared-cluster/README.md)):

| Role | What | Name |
| --- | --- | --- |
| control node | the console itself: `ansible`, `git`, `ssh` are in its image | — |
| managed nodes | 3 containers in the console's Docker (dind sidecar), Rocky Linux 9, `systemd` and `sshd` running | `node1`, `node2`, `node3` |

**Alone, not in pairs**: unlike module 1, everyone needs their own hosts
(the mock exam is individual), and three small containers are far lighter
than a kind cluster (see [Size](#size-trainer)).

Groups used across the labs:

| Host | Lab 1–2 | Lab 3 → | Lab 5 → |
| --- | --- | --- | --- |
| `node1` | `web` | `web`, `dev` | `web`, `dev` |
| `node2` | `web` | `web`, `prod` | `web`, `prod` |
| `node3` | `db` | `db`, `prod` | `db`, `prod` — MariaDB |

## Managed hosts — `lab0/`

`lab0/` provides, from `module4/`:

| Target | Does |
| --- | --- |
| `make -C lab0 image` | builds `m4-node:latest` in the console's Docker (Dockerfile in `lab0/node/`) |
| `make -C lab0 up` | network `m4` (`172.30.4.0/24`), `node1`…`node3` at **fixed IPs** `.11`–`.13`, their names in the console's `/etc/hosts`, their new host keys in `~/.ssh/known_hosts` (old ones removed) |
| `make -C lab0 reset` | `down` then `up`: the three nodes back in their **initial** state (before lab 1, lab 4's checks and the exam) |
| `make -C lab0 down` | deletes the nodes (those labelled `f021bis.module=m4` only) and the network |
| `make -C lab0 check` | ansible and sshpass in the console, image, per node: state, IP, `systemctl is-system-running`, firewalld; `node1` resolves; password login offered; dnf's baked cache present; `dl.rockylinux.org` reachable (informative) |
| `make -C lab0 pull-consoles` | trainer, from their machine: in every console, module 2's nodes `down`, then `image up` (before session 1) |

The node image (`lab0/node/`):

- `rockylinux/rockylinux:9` + `systemd`, **`systemd` as PID 1** — the labs
  start, enable and restart services. Masked: gettys, udev, logind,
  `remount-fs` and two API mounts, so that `systemctl is-system-running` says
  `running`, not `degraded`;
- `openssh-server`, `python3`, `sudo`, `firewalld` (enabled),
  `policycoreutils` installed; `nginx`, `mariadb-server` **not** installed
  (the labs do it, from dnf's cache — see below). SELinux is `Disabled` in
  a container: `policycoreutils` is there for the modules, not for
  enforcement;
- `/etc/sysconfig/chronyd` with `-x`: chronyd (lab 1 step 4) must not set
  the clock — a privileged container would steer the server's;
- **initial state = exam state**: only `root`, password login over SSH
  (`/etc/ssh/sshd_config.d/00-m4.conf`: `PermitRootLogin yes`,
  `PasswordAuthentication yes`), root password `redhat`; no `ansible` user,
  no key, no sudo rule. Lab 1 step 2 and exam task 2 are the bootstrap;
- `machine-id` and SSH host keys are removed from the image, so each node
  makes its own at boot; `up` scans the new keys into `known_hosts` as
  `node1,172.30.4.11 …`, which `ansible -k` needs (sshpass cannot answer a
  host key prompt). Host key checking itself stays on, as on the exam;
- run as module 2 runs its nodes: `--privileged`, seccomp/apparmor
  unconfined, `--cgroupns=private --tmpfs /run --tmpfs /tmp`. Not
  `--cgroupns=host -v /sys/fs/cgroup…`, which the first draft of this spec
  had: the module 2 flags were already proven in dind;
- **module 2's nodes have the same names**: `up` stops with a message if a
  `node1`…`node3` without the m4 label exists, and drops module 2's
  `/etc/hosts` block and its `~/.ssh/config` block (`Host node?`,
  `User ansible`, no host key checking), which would otherwise make a
  missing `remote_user` in lab 1 go unnoticed.

Checked on the laptop run: systemd `running` with no failed unit on all
three nodes; `ssh root@<ip>` with password `redhat` logs in; firewalld
**filters** — `curl` to an installed, started nginx is refused until
`firewall-cmd --add-service=http`, then 200 — so lab 2 step 4 and exam task
6 keep the firewall part; `reset` brings back a node without nginx and with
new host keys, in ~3 s.

**`dnf` needs no network on the nodes.** The image carries the repo
metadata and every RPM the labs and the exam install — `nginx`,
`mariadb-server`, `mariadb`, `python3-PyMySQL`, `chrony`, `tree`, `php`,
with their weak dependencies — in dnf's cache (`keepcache=True`,
`metadata_expire=-1` in `/etc/dnf/dnf.conf`). Proved by running labs 1–2
with the nodes' default route deleted. Why: Rocky's mirrorlist sent this
laptop to dead or crawling mirrors (one `dnf install chrony` failed on
curl timeouts), and each node downloaded ~111 MB of metadata after every
`reset` — ~2.6 GB per room per reset. Consequences:

- **rebuild the image before each course** (`make -C lab0 pull-consoles`):
  the baked metadata points at the current Rocky 9 minor, whose packages
  move to the vault when the next minor ships;
- a package **outside that list** still downloads, from `dl.rockylinux.org`
  (Rocky's CDN-fronted origin, set as `baseurl=` instead of the
  mirrorlist) — add it to the list in `lab0/node/Dockerfile` rather than
  rely on that;
- weak dependencies have to be in the cache: `ansible.builtin.dnf`
  installs them whatever `dnf.conf` says (nginx recommends `logrotate`).

Still **to validate in a console**: systemd booting in dind inside a kind
node (module 2's flags, but module 2 ran on a laptop too), `ssh root@node1`
and `curl http://node1` by name from the console (the console and the dind
sidecar share the pod's network namespace, so the `m4` bridge should be
reachable), and `/etc/hosts` being writable there (`up` says so if not).

## Conventions

- **One project, one repo**: `~/m4/` in the console, `git init` in lab 1,
  at least one commit per lab, a tag `labN` at the end of each. The exercises
  repo is read-only reference: step files, solutions, given files are copied
  from it, never edited in place.
- **Steps are directories**, `labN/stepM-<name>/README.md`, as in module 1:
  goal, what to write (not the whole solution), commands to check, questions
  to answer before moving on. Files the trainee is *given* (an HTML page, the
  fake app, a collection tarball) sit next to the step file. The reference
  solution of each lab is in `labN/solution/`, a complete `~/m4` at the end of
  that lab.
- **Catch-up**: `make catch-up-labN` (from `module4/`) copies
  `labN/solution/` into `~/m4` (after moving the existing one aside) and runs
  it against the nodes, so a trainee who is lost starts lab N+1 from a clean
  end state. Keep it in sync when a lab's end state changes.
- **Exam style everywhere**: FQCN modules, a `name:` on every play and task,
  file names and paths **exactly** as the step says, `ansible-doc` rather
  than the web.
- **The test of a step is the second run**: every step that changes hosts
  ends with "run it again, `changed=0`" and a check *on the host*
  (`ansible … -m command`, `curl`, `ssh`), not just the recap.
- **No secret in clear in Git** from lab 5 on; the Vault password file is
  `~/.vault_pass` (mode 600), outside the repo.

## Prerequisites

| Tool | Where |
| --- | --- |
| `ansible` (ansible-core 2.16.3, from Ubuntu 24.04) | console image; Ubuntu's `ansible` 9.x bundles ansible.posix 1.5.4, community.general 8.3.0, community.mysql 3.8.0, community.crypto 2.17.1 (checked in an `ubuntu:24.04` container; confirm in a console **(to validate)**) |
| `git`, `ssh`, `ssh-keygen`, `ssh-copy-id`, `curl` | console image (`ssh-copy-id` is in `openssh-client`) |
| `sshpass` | needed by `ansible -k` (password SSH, lab 1 step 2) — added to `shared-cluster/console/Dockerfile` in `f021bis-console:3`; consoles still on `:2` lack it (`make -C lab0 check` says so) |
| `docker` | console image (dind sidecar), for `lab0` only |

## Lab 1 — inventory and ad-hoc tasks (session 1)

Slides: *Session 1*. 40 min.

| | Step | ~ |
| --- | --- | --- |
| 1 | project dir, Git repo, `ansible.cfg` | 5 min |
| 2 | bootstrap user `ansible`: key, sudo | 10 min |
| 3 | inventory: `web`, `db`, `prod` | 5 min |
| 4 | install a package, create a user, start a service | 15 min |
| 5 | run it all again, compare | 5 min |

Start: `make -C lab0 reset` (root + password only).

1. `~/m4/`, `git init`; `ansible.cfg` with `inventory = ./inventory`,
   `remote_user = ansible`, `[privilege_escalation] become = true`;
   `ansible --version` must show `~/m4/ansible.cfg`. Question: what happens
   if the dir is world-writable?
2. `ssh-keygen -t ed25519`; **ad-hoc only**, as `root` with `-u root -k`
   and `-i node1,node2,node3,` (no inventory yet): user `ansible` in
   `wheel`, its `authorized_key`, `/etc/sudoers.d/ansible` with `NOPASSWD`,
   validated with `visudo -cf %s`. Kept in `~/m4/bootstrap.sh`, which lab 4
   and the exam reuse.
3. INI inventory: `[web] node[1:2]`, `[db] node3`, `[prod:children] web db`;
   `ansible-inventory --graph`; the `-i` dropped from `bootstrap.sh`.
4. Ad-hoc, no `-u`/`-k`/`-b`: `chrony` installed, `chronyd` started and
   enabled, user `devops` created, `/etc/motd` with `content=`; find each
   module with `ansible-doc -l` / `-s`. Kept in `~/m4/adhoc.sh`. chronyd
   runs with `-x` (set in the node image): it must not steer the server's
   clock.
5. Run every command of steps 2 and 4 again; add a `command` and a `shell`
   one; explain which stay `changed`.

End state: `ansible all -m ansible.builtin.ping` green with no option; repo
committed, tag `lab1`. Written: [`lab1/`](lab1/), `make catch-up-lab1`;
findings at the end of `lab1/README.md`.

## Lab 2 — a web service, idempotent (session 2)

Slides: *Session 2*. 40 min.

| | Step | ~ |
| --- | --- | --- |
| 1 | install the web server on `web` | 5 min |
| 2 | deploy a page with the host name in it | 10 min |
| 3 | config file + handler to restart | 10 min |
| 4 | open the port, start and enable the service | 5 min |
| 5 | users from a list with `loop` | 5 min |
| 6 | run twice, then change the page only | 5 min |

One playbook, `web.yml`, hosts `web`. Web server: **nginx** (the same one
lab 3 templates).

1. `ansible.builtin.dnf` (or `package`) `nginx`; `--syntax-check`,
   `--list-tasks` before the first run.
2. `ansible.builtin.copy` with `content:` → `/usr/share/nginx/html/index.html`
   containing `inventory_hostname`.
3. `ansible.builtin.copy` of a given `nginx.conf` (in `lab2/step3-config/`)
   with `notify: Restart nginx`; the handler.
4. `ansible.posix.firewalld` `http` permanent + immediate; `service` started
   and enabled.
5. `web_users` (list of dicts: `name`, `shell`) in the play's `vars:`,
   `ansible.builtin.user` with `loop`.
6. Run twice (`changed=0`); edit the page only → no restart; edit the config
   → handler runs **once**.

Checks: `curl http://node1`, `curl http://node2` from the console show each
host name. Questions in the step files: which task would break idempotence
with `shell: echo … > index.html`? when does the handler *not* run although
notified (play failed before the end — and the next run does not restart
either)? Written: [`lab2/`](lab2/) (given `nginx.conf`: the whole file,
2 workers, port 80, header `X-Managed-By: ansible`, the base of lab 3's
template), `make catch-up-lab2`; findings at the end of `lab2/README.md`.

## Lab 3 — one template, two environments (session 3)

Slides: *Session 3*. 40 min.

| | Step | ~ |
| --- | --- | --- |
| 1 | `dev` and `prod` groups, `group_vars/` | 5 min |
| 2 | template the web config: port, workers | 10 min |
| 3 | `{% for %}` over virtual hosts | 10 min |
| 4 | `{% if %}` debug block, `validate:` | 5 min |
| 5 | custom fact `env` read back in the template | 10 min |

1. Groups `dev` (`node1`) and `prod` (`node2`, `node3`); `group_vars/dev.yml`,
   `group_vars/prod.yml` with `web_port`, `web_workers`, `web_debug`,
   `web_vhosts` (list of `name`, `root`). `group_vars/all.yml` for defaults.
   Check with `ansible-inventory --host`.
2. `templates/nginx.conf.j2` replaces lab 2's static file: **the whole
   `nginx.conf`**, not a `conf.d/` snippet, so that
   `validate: nginx -t -c %s` can check it (a snippet alone fails `nginx -t`).
3. One `server {}` per vhost, `loop` in the playbook creates each `root`
   directory and its `index.html`.
4. `{% if web_debug %}` → `error_log … debug;`; break the template on purpose
   (missing `;`): the task fails, the old file is still in place.
5. `ansible.builtin.copy` of `/etc/ansible/facts.d/app.fact`
   (`[general] env=<group>`), then `setup` again (or `meta: clear_facts` /
   a second play); `ansible_local['app']['general']['env']` in a comment of
   the generated file.

Checks: `diff` of the two generated files shows only the values;
`-e web_port=9090` overrides both; `curl http://node1:<port>` per env.
Precedence quiz in the step file: the same variable in `all`, `prod`,
`host_vars/node2.yml`, `-e` — predict, then check with `debug`.

## Lab 4 — split it into roles (session 4, unguided)

Slides: *Session 4*. 45 min. **No step files**: `lab4/README.md` gives the
target and the checks below, nothing else. The trainer walks around and
notes who is stuck where (assessment checkpoint), without fixing.

Target:

| Role | Does |
| --- | --- |
| `common` | packages (`chrony`, `tree`), `chronyd`, the custom fact of lab 3 |
| `web` | lab 3's template and handler, every tunable in `defaults/main.yml`, `meta/argument_specs.yml` for `web_port` |
| `app` | the page and vhosts; `meta/main.yml` **depends on** `web` |

- `roles/` created with `ansible-galaxy role init`; a README per role
  (purpose, variables, dependencies, example);
- `site.yml`: plays that only list roles (`common` on `all`, `app` on `web`);
- `collections/requirements.yml` with `ansible.posix` and the given tarball
  `lab4/files/community-crypto-<version>.tar.gz` (type `file`), installed
  into `./collections` (`collections_path` in `ansible.cfg`); the tarball is
  shipped in the repo so no Galaxy access is needed **(choose the version
  from what the console's ansible-core supports)**;
- Git: one commit per role, tag `lab4`.

Checks (given to the trainees):

```sh
ansible-playbook site.yml --syntax-check
make -C ~/trainings_exercises/f021bis/module4/lab0 reset   # clean hosts
# … bootstrap again with lab 1's ad-hoc commands
ansible-playbook site.yml            # changed > 0
ansible-playbook site.yml            # changed=0
ansible-playbook site.yml --tags web --list-tasks
ansible-doc -t role -r roles web
git log --oneline && git tag
```

`lab4/solution/` is shown during the correction (session 4, last 15 min),
not before.

## Lab 5 — integrated deployment (session 5)

Slides: *Session 5*. 50 min.

| | Step | ~ |
| --- | --- | --- |
| 1 | role `db`, password from **Vault** | 10 min |
| 2 | vault password file, `ansible.cfg` | 5 min |
| 3 | `assert` the preconditions | 5 min |
| 4 | `block` / `rescue` + health check | 15 min |
| 5 | verification play | 5 min |
| 6 | break the config, watch the rollback | 10 min |

Given: a **fake app**, `lab5/files/app.py` (Python 3 standard library only):
reads `port` and `db_host` from `/etc/app/app.conf`, serves `/health` (200
when the config parses and the DB port answers, 500 otherwise), and its
systemd unit `app.service`. It replaces a real application so the lab does
not depend on one; it runs on `web` behind nothing (its own port, e.g. 8000).

1. Role `db` on `node3`: `mariadb-server`, `python3-PyMySQL`, service, a
   database `shop` and user `app` (`community.mysql`) whose password is
   `db_password`; the vars/vault pattern: `group_vars/db/vars.yml`
   (`db_password: "{{ vault_db_password }}"`) and `group_vars/db/vault.yml`
   encrypted. `no_log: true` on the user task.
2. `~/.vault_pass` (600), `vault_password_file` in `ansible.cfg`,
   `.gitignore`; `ansible-vault view` works without a prompt.
3. Role `app`: `ansible.builtin.assert` on memory, `app_port | int > 1024`,
   `db` group not empty, with a `fail_msg`.
4. `block`: `template` of `app.conf` with `backup: true`, restart, `uri` on
   `/health` with `until`/`retries`; `rescue`: copy the backup back
   (`remote_src: true`), restart; `always`: report.
5. `verify.yml`: from `localhost`, `uri` to each `web` host's `/health`,
   `assert` status 200.
6. `-e app_db_port=1` (or a wrong port in `group_vars`): the block fails, the
   rescue restores the previous config, `verify.yml` is still green; then
   `--check --diff` on the fixed value before running it for real.

Checks: `git grep -n S3cr3t` returns nothing;
`head -1 group_vars/db/vault.yml` is `$ANSIBLE_VAULT;1.1;AES256`; second run
`changed=0`. End of the session: pairs review each other's repo against the
checklist on the slides (*Code review, exam checklist*).

## Mock exam (session 6)

Slides: *Session 6*. 65 min, individual, no internet (`ansible-doc`, `man`
allowed), a **fresh** directory `~/exam` in the console, previous repos not allowed.

`exam/` must contain:

| File | What |
| --- | --- |
| `README.md` | the statement: 10 tasks, exact names, paths and values; points per task |
| `files/` | what the statement gives: a collection tarball, a page, the hardware-report expectations |
| `grade.sh` | runs **after** the time, from the trainer's side or the trainee's console: checks the **hosts** and the expected files, prints points per task and per skill; never runs the trainee's playbooks except task 10's second run |
| `solution/` | the reference project, shown in the correction |

Start: `make -C lab0 reset` for everyone **before** the session (hosts back to
root + password).

Tasks — the statement details them, the slide summarises them in the same
order:

| # | Task | Skill (points) | `grade.sh` checks |
| --- | --- | --- | --- |
| 1 | `ansible.cfg` and `inventory`: groups `web` (node1, node2), `db` (node3), `prod` (children of both) | inventory (5) | files exist, `ansible-inventory --graph` |
| 2 | bootstrap: user `automation`, key, passwordless sudo, on every host | inventory (10) | `ssh automation@nodeN sudo -n true` |
| 3 | `packages.yml`: `php` on `web`, `mariadb` on `db`, `tree` everywhere | playbooks (10) | `rpm -q` per host |
| 4 | install the given collection tarball into `./collections` | roles (5) | `ansible-galaxy collection list -p collections` |
| 5 | role `motd`: `/etc/motd` with host name, IP, and `env` from a custom fact `/etc/ansible/facts.d/custom.fact` | variables (10) | file content per host |
| 6 | role `web`: nginx on port from `group_vars`, page with host name, handler, firewall | playbooks (10), roles (10) | `curl`, `systemctl is-enabled` |
| 7 | `secret.yml` encrypted with password in `vault_pass.txt`, holding `user_password` | Vault (5) | `ansible-vault view --vault-password-file` |
| 8 | `users.yml`: users from a given list, password from Vault (hashed), only on `prod`, groups created | variables (10) | `getent passwd`/`group`, login hash not empty |
| 9 | `report.yml`: `/root/report.txt` from a template, `NONE` when a disk (`vdb`) is missing — `block`/`rescue` or `default` | Vault/errors (10) | file content |
| 10 | `site.yml` imports 3, 5, 6, 8; second run `changed=0` | verification (10), roles (5) | `ansible-playbook site.yml` → `changed=0` |

Total 100, grouped as on the slide (*Instructions and grading*): inventory 15,
playbooks 20, variables 20, roles 20, Vault/errors 15, verification 10. 70 is
this course's benchmark, **not** Red Hat's pass mark.

Before using the statement: EX407 is retired; check the current Red Hat
exam (EX294 for RHCE, EX374/EX467 for Ansible Automation Platform) and its
objectives, and adjust tasks that rely on tools the exam now requires
(e.g. `ansible-navigator`) **(to validate)**.

## Size (trainer)

Measured on the laptop (not yet on the server): the node image is 751 MB
(uncompressed) per console, ~300 MB of it dnf's cache (metadata and the
labs' RPMs); building it downloads that once per console, where three
nodes per reset used to fetch the metadata each; an idle node uses ~41 MiB, ~57 MiB with nginx
installed and running. Three nodes are therefore well under 300 MiB per
console before MariaDB; measure again with lab 5's end state (MariaDB, the
fake app) on the first dry run and replace this paragraph with the numbers,
as in module 1.

Before session 1: roll the consoles to `f021bis-console:3` (sshpass), then
`make -C lab0 pull-consoles` (module 2's nodes down, image built and nodes up
in every console), `make -C lab0 check` and `ansible all -i node1,node2,node3
-m ping -u root -k` from one console to prove the path. Before session 6: `make -C lab0 reset` in every
console.
