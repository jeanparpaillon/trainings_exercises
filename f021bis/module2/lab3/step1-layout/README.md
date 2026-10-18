# Step 1 — Kubespray's layout, our inventory

**Slides:** Kubespray — inventory and `group_vars`, playbooks · **~10 min**

Kubespray is code we **run**, never edit: `~/kubespray` stays at its tag.
Everything that is ours — the inventory, its `group_vars`, our choices —
goes into `~/m2/inventory`, in our repo.

## Read Kubespray

```sh
cd ~/kubespray
git describe --tags                        # KUBESPRAY_VERSION
less cluster.yml playbooks/cluster.yml     # the plays: which hosts, which roles
ls roles/ roles/kubernetes/
ls inventory/sample/ inventory/sample/group_vars/*
less inventory/sample/inventory.ini
cat ansible.cfg
```

## Copy the sample's `group_vars`

Into `~/m2/inventory/group_vars/`, **without overwriting** lab 1's
`all/main.yml` and `all/vault.yml` — no file collides, but check it:

```sh
cd ~/m2
diff <(ls ~/kubespray/inventory/sample/group_vars/all) <(ls inventory/group_vars/all)
cp -r --update=none ~/kubespray/inventory/sample/group_vars/. inventory/group_vars/
find inventory -type f | sort
```

Lab 1's `hosts.yml` **is** the inventory: same group names. Not copied:
`inventory.ini` (ours is `hosts.yml`).

## `ansible.cfg`: what Kubespray expects from it

We run Kubespray's playbooks from `~/m2`, so **our** `ansible.cfg` applies,
not `~/kubespray/ansible.cfg`. Add to ours what Kubespray depends on:

| Setting | Section | Value | Why |
| --- | --- | --- | --- |
| `roles_path` | `[defaults]` | `./roles:~/kubespray/roles` | or `cluster.yml` finds none of its roles |
| `library` | `[defaults]` | `~/kubespray/library` | its own modules |
| `gathering` | `[defaults]` | `smart` | |
| `fact_caching`, `fact_caching_connection`, `fact_caching_timeout` | `[defaults]` | `jsonfile`, `/tmp/m2-facts`, `86400` | step 5: `scale.yml --limit=node3` needs the **other** nodes' facts |
| `force_valid_group_names` | `[defaults]` | `ignore` | |
| `callbacks_enabled` | `[defaults]` | `ansible.posix.profile_tasks` | the time of each task, at the end |
| `ignore_patterns` | `[inventory]` | `artifacts, credentials` | step 4: `inventory/artifacts/admin.conf` is not an inventory file |
| `pipelining` | `[ssh_connection]` | `True` | one SSH round trip per task instead of several: much faster |

```sh
ansible-inventory --graph
ansible all -m ansible.builtin.ping
git add -A && git commit -m "Kubespray's sample group_vars, ansible.cfg"
```

## Questions

- Which group gets etcd, in the sample? In ours? Why an odd number?
- `k8s_cluster`: the sample's `inventory.ini` does not define it. Find where
  Kubespray builds it (`grep -rn k8s_cluster ~/kubespray/roles/dynamic_groups`).
  Is ours, explicit, a problem?
- Upgrading Kubespray means a new tag in `~/kubespray`. What would you diff
  against your `inventory/group_vars/` before running anything?
