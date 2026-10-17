# Step 4 — idempotence: the second run, `--check --diff`

**Slides:** Ansible recap — idempotence, check mode, diff · **~10 min**

## The second run is the test

```sh
ansible-playbook site.yml
ansible-playbook site.yml          # changed=0 — anything else is a bug
```

If the second recap is not `changed=0`, run it with `-v`, find the task, and
fix it before going on: every step of this module ends with this test.

## A change, reviewed before it is applied

Add to the defaults one module and one sysctl:

- `nf_conntrack` to `k8s_modules` (kube-proxy's connection tracking);
- `net.core.somaxconn: 32768` to `k8s_sysctls` (listen backlog; per network
  namespace).

Then the dry run, as a reviewer would want it before a production run:

```sh
ansible-playbook site.yml --check --diff
ssh ansible@node2 'cat /etc/modules-load.d/k8s.conf; sysctl net.core.somaxconn'   # unchanged?
```

Read it: the template shows a diff, the sysctl only says `changed` —
`ansible.posix.sysctl` does not support `--diff`. And the handler: it
**ran** in check mode, reported `changed`, and restarted nothing.

Apply, then the test again:

```sh
ansible-playbook site.yml
ansible-playbook site.yml          # changed=0
git commit -am "nf_conntrack, somaxconn"
```

## Break it on purpose

Replace the `blockinfile` task by the version everyone writes once:

```yaml
- name: Every node of the inventory in /etc/hosts (the wrong way)
  ansible.builtin.shell: |
    {% for host in groups['all'] if hostvars[host].ansible_host is defined %}
    echo "{{ hostvars[host].ansible_host }} {{ host }} # shell" >> /etc/hosts
    {% endfor %}
```

```sh
ansible-playbook site.yml
ansible-playbook site.yml                       # changed=?
ansible-playbook site.yml --check               # what does check mode say about it?
ssh ansible@node2 cat /etc/hosts
```

Revert, and clean up. Reverting the task does not undo what it did:

```sh
git checkout roles/k8s_node_prereqs/tasks/main.yml
ansible k8s_cluster -m ansible.builtin.lineinfile \
  -a 'path=/etc/hosts regexp=" # shell$" state=absent unsafe_writes=true'
ansible-playbook site.yml          # changed=0
ssh ansible@node2 cat /etc/hosts
```

## Questions

- Which tasks of your role report `changed` in check mode without anything
  being different afterwards? Which ones say nothing at all about what a
  real run would do (`shell`)? What does that make `--check` worth on a
  playbook full of `shell`?
- The `shell` task could have been made "idempotent" with `changed_when:
  false`. Would the recap then tell the truth? Would `/etc/hosts`?
- `cache_valid_time` on the `apt` task: what does the second run do without
  it, and is that a change?
