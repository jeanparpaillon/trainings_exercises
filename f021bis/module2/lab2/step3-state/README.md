# Step 3 — read back, wait, re-run, and what Ansible does not delete

**Slides:** Managing manifests with Ansible — state and waiting · **~10 min**

A green recap says the API accepted the objects, not that the application
runs. Read the cluster back.

## Read back

At the end of `app.yml`:

1. `kubernetes.core.k8s_info` on Deployment `web`, `wait: true`,
   `wait_condition` `type: Available`, `status: "True"`, a `wait_timeout`;
   `register` it;
2. `ansible.builtin.assert` that its `status.readyReplicas` is
   `app_replicas`;
3. the same number through a lookup, in a `debug`:
   `lookup('kubernetes.core.k8s', kind='Deployment', namespace='web', resource_name='web', …)`.
   It fails as written: `module_defaults` apply to **modules** only. Pass the
   connection to the lookup yourself.

## Re-run, dry-run

```sh
ansible-playbook k8s/app.yml
ansible-playbook k8s/app.yml                     # changed=0
```

Change `app_replicas` in `vars/dev.yml`, then

```sh
ansible-playbook k8s/app.yml --check --diff
```

The diff is the object as the API returns it, `managedFields` included:
look for `replicas`. And your `assert` fails: read why — in check mode,
nothing was applied, so the cluster still has the old count. Skip it in
check mode (`when: not ansible_check_mode`), check again, then apply.

## What Ansible does not delete

Rename the ConfigMap `web-page` → `web-content`, in its template and where
the Deployment mounts it. Run, then

```sh
kubectl -n web get configmaps
```

**`web-page` is still there.** Ansible applies what the playbook says now;
it has no record of what it created before. Add the task that removes it —
`state: absent`, `kind`, `namespace`, `name` — run twice, commit.

```sh
git commit -am "read back; web-page -> web-content"
```

## Questions

- Who deletes the old ConfigMap if nobody writes that task?
- When can the `state: absent` task be removed again? (Think: several
  clusters, `iac` today, `spray` in lab 3.)
- This is the *prune* row of session 3's comparison table. What would
  `kubectl apply --prune` or Flux need to know that Ansible does not?
