# Step 3 — `cluster.yml`

**Slides:** Kubespray — playbooks · **~35 min**

```sh
cd ~/m2
time ansible-playbook -i inventory ~/kubespray/cluster.yml 2>&1 | tee cluster.log
```

`become` comes from our `ansible.cfg`; the inventory is ours, the playbook
Kubespray's. With the trainer's predownload done, it takes **~8 min** (dry
run: 8 min 6 s, of which ~5 min of image pulls). Without it, the binaries
alone took 40 min on the dry run.

## While it runs

In another tab, read along:

```sh
less ~/kubespray/playbooks/cluster.yml
```

- Match the role names scrolling by (`kubernetes/preinstall`,
  `container-engine/containerd`, `download`, `etcd`, `kubernetes/control-plane`,
  `kubernetes/node`, `network_plugin/flannel`, …) with the plays of
  `cluster.yml`. Which plays target `etcd`, `kube_control_plane`,
  `kube_node`, `k8s_cluster`?
- Where is kubeadm called? `grep -rn 'kubeadm init\|kubeadm.*join' ~/kubespray/roles --include=*.yml`.
  What does Kubespray do **before** kubeadm that kubeadm left to you in
  module 1?
- Where do the binaries land on the nodes? `ssh node2 ls /var/tmp/releases`
  (and why not `/tmp`: `zz-containers.yml`).

## If it fails

Read the **failed task** (`TASK [...]`, then `fatal:`), not the last line.
Fix the variable in your inventory, commit, run again: Kubespray does not
resume, it re-checks everything — faster the second time, the downloads are
there. One `fatal:` is expected and ignored (`...ignoring`): Kubespray
probing for an etcd that is not installed yet (`etcd --version`).

## At the end

```sh
tail -40 cluster.log            # PLAY RECAP: failed=0 everywhere; the slowest tasks
ls inventory/artifacts/
```

## Questions

- `node3` is in the inventory: what did `cluster.yml` do to it, and why
  (`PLAY RECAP`)?
- Which task took longest, and what would make it shorter for a room of
  four pairs?
