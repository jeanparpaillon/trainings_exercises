# Lab 1 — Ansible refresher

**Slides:** *Session 1* (`ansible_basics.md`), then *Lab 1*
(`lab_ansible_basics.md`) · **~60 min**

An Ansible project in Git that prepares `node1`…`node3` for Kubernetes,
**idempotent**, with no secret in clear. A refresher of formation-prod day
3, aimed at what lab 3 needs: the inventory uses Kubespray's groups, and the
role prepares the nodes without installing anything Kubespray installs.

| Step | | ~ |
| --- | --- | --- |
| [step1-project](step1-project/) | project, `ansible.cfg`, inventory with Kubespray's groups | 10 min |
| [step2-facts](step2-facts/) | facts: what a container node shares with its host | 10 min |
| [step3-role](step3-role/) | role `k8s_node_prereqs` | 25 min |
| [step4-idempotence](step4-idempotence/) | idempotence: second run, `--check --diff` | 10 min |
| [step5-vault](step5-vault/) | a secret in Vault | 5 min |

| File | What it is |
| --- | --- |
| [`step3-role/defaults.yml`](step3-role/defaults.yml) | the role's defaults, to complete |
| [`solution/`](solution/) | `~/m2` at the end of the lab; its `vault.yml` is encrypted with `m2-solution` |

**Start**: `make -C lab0 check` green, in the driver's console. Everything
runs from `~/m2` with the venv active — not the console's own `ansible`
(2.16), which Kubespray refuses:

```sh
source ~/.venvs/m2/bin/activate
make -C ~/trainings_exercises/f021bis/module2/lab0 check
```

**End state** (start of labs 2 and 3): `~/m2`, a Git repo tagged `lab1`,
with `ansible.cfg`, `inventory/hosts.yml`,
`inventory/group_vars/all/{main,vault}.yml`, role `k8s_node_prereqs`,
`site.yml`; `node1` and `node2` prepared, `node3` untouched. From nothing:
`make catch-up-lab1` in `module2/` (moves an existing `~/m2` aside, re-keys
the solution's vault to your `~/.vault_pass`, runs `site.yml`).

## What was found on a local run

The solution was run against three `ubuntu:24.04` systemd + sshd containers
(privileged, `/lib/modules` mounted, as the spec describes the lab 0 nodes)
with ansible-core 2.17, then 2.19, and again on `lab0`'s own nodes during
lab 3's dry run. Not yet on the f021bis consoles.

- **A missing `~/.vault_pass` breaks every command** once `ansible.cfg`
  names it, `ansible-inventory` included — hence step 1 creates it.
- **`/etc/hosts` cannot be replaced** in a container (Docker bind-mounts it):
  `blockinfile` fails with `[Errno 16] Device or resource busy` unless
  `unsafe_writes: true`. Step 3 lets them hit it.
- **`password_hash` needs `passlib`** in the venv: ansible-core ≥ 2.17 no
  longer falls back to Python's `crypt`. Kubespray v2.32.0's
  `requirements.txt` pins `passlib==1.7.4`, so the venv has it.
- Re-run with ansible-core 2.19 (Kubespray v2.32.0's pin) during lab 2:
  same results.
- **Handlers run in check mode**: the handler is reported `changed` and
  restarts nothing. `ansible.posix.sysctl` has no `--diff` output.
- **`net.bridge.*` sysctls exist only once `br_netfilter` is loaded**, so
  the role flushes handlers between the modules and the sysctls.
- `ansible_virtualization_type` is `docker`; `ansible_kernel`,
  `ansible_memtotal_mb`, `ansible_processor_vcpus`, `ansible_swaptotal_mb`
  are the host's, identical on every node.
- `ansible-lint` flags only `var-naming[no-role-prefix]` (`k8s_modules`
  instead of `k8s_node_prereqs_modules`): kept, the names are shorter to
  read on the slides.
