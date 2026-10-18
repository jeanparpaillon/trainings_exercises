# Step 8 — `upgrade-cluster.yml`, `KUBE_FROM` → `KUBE_TO`

**Slides:** *Lab 3 — upgrade* · **~30 min**

Module 1 lab 3 was this procedure by hand: control plane, then each node —
cordon, drain, upgrade, uncordon — with a load generator watching. Here it
is one variable and one playbook.

## The change, in Git first

In `inventory/group_vars/k8s_cluster/k8s-cluster.yml`:
`kube_version: 1.36.4` (`KUBE_TO`). Same Kubespray release: both versions
are in its supported range.

```sh
git commit -am "spray: Kubernetes KUBE_TO"
```

## Watch, in other tabs

```sh
~/trainings_exercises/f021bis/module2/lab3/load           # from step 7, still running
kubectl get nodes -w
kubectl get pods -l app=web -o wide -w
```

## Upgrade

```sh
time ansible-playbook -i inventory ~/kubespray/upgrade-cluster.yml 2>&1 | tee upgrade.log
```

Dry run: **16 min** (961 s), of which ~10 min downloading the new binaries
and images; **1 failed request out of ~4,300**, on `node1`'s NodePort, right
after the control plane's `kubeadm upgrade`.

```sh
kubectl get nodes
kubectl version
grep -E 'TASK \[upgrade/(pre|post)-upgrade : (Cordon|Drain|Uncordon) node\]' -A1 upgrade.log
```

## Questions

Compared with module 1 lab 3:

- In which order did the nodes go, and in which play of
  `~/kubespray/playbooks/upgrade_cluster.yml`? What about with three control
  planes?
- Who drained? Who uncordoned? What did you check by hand in module 1 that
  nothing checked here?
- What controls how many nodes at a time (`serial`, default `20%`, and `1`
  for control planes)? How long a drain may take (`drain_timeout`,
  `drain_grace_period`, `drain_retries` in
  `~/kubespray/roles/upgrade/pre-upgrade/defaults/main.yml`)? What happens
  when a PDB blocks the drain (`upgrade_node_fail_if_drain_fails`)?
- Count the failed requests in the `load` tab. Where did they come from, and
  what would have removed them?
- Where are the `web` pods now? Why does nothing move them back?
