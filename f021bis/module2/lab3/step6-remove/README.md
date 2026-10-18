# Step 6 — remove `node2`: `remove-node.yml`

**Slides:** Kubespray — playbooks (day 2) · **~20 min**

Removing a node is the reverse order of adding one: the **cluster** first
(drain, reset, delete from the API), **then** the inventory.

## Something to protect

[`web.yaml`](web.yaml): a Deployment `web`, 3 replicas, and a PDB
`minAvailable: 2`.

```sh
kubectl apply -f ~/trainings_exercises/f021bis/module2/lab3/step6-remove/web.yaml
kubectl rollout status deploy web
kubectl get pods -l app=web -o wide          # some on node2?
kubectl get pdb web                           # ALLOWED DISRUPTIONS 1
```

In another tab:

```sh
kubectl get pods -l app=web -o wide -w
```

## Remove it

With `node2` **still in the inventory**:

```sh
time ansible-playbook -i inventory ~/kubespray/remove-node.yml -e node=node2
```

It asks for confirmation (type `yes`), then drains `node2` — the PDB lets
one pod go at a time — resets it (`kubeadm reset`, containerd, CNI, files),
and deletes the Node object.

## Then the inventory

Move `node2` from `kube_node` back to `spare`. Commit.

```sh
kubectl get nodes
kubectl get pods -l app=web -o wide
git commit -am "node2 removed, back in spare" && git tag lab3b
```

## Questions

- What if someone runs `cluster.yml` with `node2` still in `kube_node`?
- What did the reset leave on `node2`? `ssh node2 ls /etc/kubernetes
  /var/lib/kubelet /var/tmp/releases; ssh node2 systemctl is-active containerd`.
  Could `scale.yml --limit=node2` bring it back, and how long would it take?
- Kubespray's `drain_grace_period`, `drain_timeout`, `drain_retries`
  (`~/kubespray/roles/remove_node/pre_remove/defaults/main.yml`): what happens
  with a PDB that never allows a disruption?
