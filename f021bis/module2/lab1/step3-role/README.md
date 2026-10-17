# Step 3 — role `k8s_node_prereqs`

**Slides:** Ansible recap — roles · **~25 min**

A role that **prepares** a node for Kubernetes, without installing it:

- **no containerd, no kubelet**: Kubespray installs them in lab 3, and a role
  that did too would fight it;
- **no `swapoff`**: on these nodes it would switch off the server's swap
  (step 2). The role checks, and fails with an explanation.

## The role

```sh
cd ~/m2
ansible-galaxy role init roles/k8s_node_prereqs
rm -r roles/k8s_node_prereqs/{tests,vars,files}       # not used
cp ~/trainings_exercises/f021bis/module2/lab1/step3-role/defaults.yml \
   roles/k8s_node_prereqs/defaults/main.yml
```

Complete the TODOs of `defaults/main.yml` first. Then write
`tasks/main.yml`, in this order, every module by its FQCN
(`ansible-doc <module>` for the parameters):

1. **No swap** — `ansible.builtin.assert` that `ansible_swaptotal_mb == 0`,
   with a `fail_msg` saying why the role checks rather than fixes. First, so
   that a node that does not qualify fails before anything is changed.
2. **Packages** — `ansible.builtin.apt`, the list `k8s_packages`,
   `update_cache: true` with a `cache_valid_time` (without it, every run
   updates the cache: is that a change?).
3. **Modules at boot** — `ansible.builtin.template` to
   `/etc/modules-load.d/k8s.conf`, the template (`templates/k8s.conf.j2`) a
   loop over `k8s_modules`; it `notify:`s a handler (`handlers/main.yml`)
   that restarts `systemd-modules-load` with
   `ansible.builtin.systemd_service`.
4. **Modules now** — the sysctls of the next task do not exist until
   `br_netfilter` is loaded, and handlers run at the **end** of the play.
   Find the one-line task that runs them here instead.
5. **Sysctls** — `ansible.posix.sysctl`, a loop over `k8s_sysctls`
   (`dict2items`), into `/etc/sysctl.d/99-k8s.conf`.
6. **`/etc/hosts`** — `ansible.builtin.blockinfile`, a block with one line
   `<ansible_host> <name>` per host of the inventory: a Jinja `for` loop
   over `groups['all']`, reading `hostvars[host].ansible_host`. Skip hosts
   that have no `ansible_host` (lab 2 adds `localhost` to this inventory).
   Your own `marker:`.

And `site.yml`, one play: `hosts: k8s_cluster`, the role.

## Run it

```sh
ansible-playbook site.yml
```

If **No swap** fails on every node, the server has swap: that is the
trainer's to fix, not yours (step 2) — call them.

The `/etc/hosts` task fails: read the error. `/etc/hosts` in a container is
a file Docker **bind-mounts** from outside; Ansible writes files atomically
(a temporary file, then `rename`), and a mount point cannot be renamed over.
The module has a parameter for exactly this case: find it in `ansible-doc
ansible.builtin.blockinfile`, set it **on this task only**, with a comment.
(Kubespray's own `/etc/hosts` task has it too.)

## Check

On the nodes, not in the recap:

```sh
ssh ansible@node2 cat /etc/hosts
ssh ansible@node2 cat /etc/modules-load.d/k8s.conf /etc/sysctl.d/99-k8s.conf
ssh ansible@node2 'lsmod | grep br_netfilter; sysctl net.bridge.bridge-nf-call-iptables'
ssh ansible@node3 cat /etc/hosts          # not in k8s_cluster: untouched
```

```sh
git add -A && git commit -m "role k8s_node_prereqs"
```

## Questions

- `lsmod` on `node3` — untouched by the role — shows `br_netfilter` too.
  Why?
- Kubespray will write its own block into `/etc/hosts`. Why does it not
  matter that ours is there too — and why would it matter if both used the
  same `marker`?
