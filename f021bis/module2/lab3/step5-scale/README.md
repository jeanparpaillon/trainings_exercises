# Step 5 — add `node3`: `scale.yml`

**Slides:** Kubespray — playbooks (day 2) · **~15 min**

Adding a worker is an inventory change, then a playbook — never a command
typed on the node.

## The inventory first

In `inventory/hosts.yml`, move `node3` from `spare` to `kube_node` (leave
`spare:` as an empty group). Commit: the cluster's definition changes before
the cluster does.

```sh
ansible-inventory --graph
git commit -am "node3 joins kube_node"
```

## Facts, then scale

Kubespray's procedure (`~/kubespray/docs/operations/nodes.md`): refresh the
facts of **every** node first, then run `scale.yml` on the new one only.

```sh
time ansible-playbook -i inventory ~/kubespray/playbooks/facts.yml
time ansible-playbook -i inventory ~/kubespray/scale.yml --limit=node3
```

Dry run: ~4 min for both, binaries predownloaded; the recap shows
`changed=0` on `node1` and `node2`.

## Check

```sh
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide | grep node3        # flannel, kube-proxy, nginx-proxy
```

## Questions

- Why `--limit=node3`? What would `cluster.yml` without it have done, and
  how long would it have taken?
- `scale.yml --limit=node3` still needs `node1`'s IP, the cluster's CA, the
  join token. Where does it get facts about hosts it does not contact? (Look
  at `fact_caching` in your `ansible.cfg`, and `ls /tmp/m2-facts`.)
- `node3` never ran lab 1's role. Did it matter? Should it have?
