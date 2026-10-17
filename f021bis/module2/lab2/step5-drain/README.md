# Step 5 — an operation: cordon, drain, uncordon

**Slides:** `kubernetes.core` — main modules (operations) · **~10 min**

Module 1 lab 3 drained nodes by hand. The same procedure as a playbook,
which anyone can run the same way at 3 a.m.

## Make `web` drain-safe first

In `app.yml`: a PodDisruptionBudget `web`, `minAvailable: 1`, from a
template (`k8s/templates/pdb.yaml.j2`), and `app_replicas: 2` in dev if it
is not already. Run, and check:

```sh
kubectl -n web get pdb                        # ALLOWED DISRUPTIONS 1
kubectl -n web get pods -o wide               # which node?
```

## The playbook

`k8s/maintenance.yml`, run with `-e node=<name>`:

1. `assert` that `node` is defined (a clear message, not a Jinja error);
2. `kubernetes.core.k8s_drain`, `state: drain`, `delete_options`:
   `ignore_daemonsets`, `delete_emptydir_data`, `wait_timeout`;
3. `ansible.builtin.pause` — standing for the maintenance itself;
   `seconds: "{{ maintenance_seconds | default(30) }}"`;
4. `k8s_drain`, `state: uncordon`;
5. `k8s_info` on Deployment `web`, waiting for `Available`.

In a second tab, before running it:

```sh
kubectl -n web get pods -o wide -w
```

```sh
ansible-playbook k8s/maintenance.yml -e node=iac-worker
kubectl get nodes
kubectl -n web get pods -o wide
git add -A && git commit -m "maintenance.yml"
```

## Questions

- After the uncordon, where are the `web` pods? Why does nothing move them
  back?
- Compare with module 1 lab 3: what did you check by hand before draining
  that this playbook does not check? Who refused the evictions that would
  have broken `web`?
- `-e node=iac-control-plane`: what would happen with a single replica and
  the PDB?
