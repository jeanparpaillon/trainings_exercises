# Step 2 — `group_vars`: the decisions

**Slides:** Kubespray — inventory and `group_vars` (*Decisions, not settings*) · **~15 min**

The sample's `group_vars` are Kubespray's defaults, commented. Each line you
change is a decision about **your** cluster; write why next to it.

## `inventory/group_vars/k8s_cluster/k8s-cluster.yml` and `addons.yml`

| Variable | File | Value | Why here |
| --- | --- | --- | --- |
| `kube_version` | `k8s-cluster.yml` (add it, at the top) | `KUBE_FROM` (`1.35.8`) | lab 3c upgrades it; the release supports `1.34.0`–`1.36.4` |
| `container_manager` | `k8s-cluster.yml` | `containerd` (the default) | the only runtime module 1 used |
| `kube_network_plugin` | `k8s-cluster.yml` | `flannel` | the lightest: no BGP, no policy engine. VXLAN works in our nested nodes |
| `kube_proxy_mode` | `k8s-cluster.yml` | `iptables` | `ipvs`, the default, needs the IPVS modules in the **server's** kernel |
| `enable_nodelocaldns` | `k8s-cluster.yml` | `false` | a dummy interface and a link-local IP on every node: one more kernel dependency, and memory |
| `cluster_name` | `k8s-cluster.yml` | `spray.local` | the cluster's name: kubeconfig context, certificates |
| `dns_domain` | `k8s-cluster.yml` (already there, further down: change **that** line — a second one only gets `[WARNING]: Found duplicate mapping key`, and the last one wins) | `cluster.local` | defaults to `cluster_name`; but Flux's `install.yaml` (step 9) hardcodes `svc.cluster.local`, as many charts do — on the dry run Flux could not reach its own source-controller |
| `kubeconfig_localhost` | `k8s-cluster.yml` | `true` | `admin.conf` copied to `inventory/artifacts/` (step 4) |
| `etcd_deployment_type` | `all/etcd.yml` | `host` (the default) | etcd as a systemd unit — kind and module 1 ran it as a static pod |

Look at `addons.yml` too: what is enabled by default? (Nothing to change.)

## `inventory/hosts.yml`: `node1` is a worker too

Add `node1` to `kube_node`. A control plane that is also in `kube_node` is
not tainted: it takes workloads. With two nodes, this is what lets an
upgrade (lab 3c) drain one node while the other keeps the application — the
compromise module 1 made with `kubectl taint … -`. In production, keep
workloads off the control plane.

```sh
ansible-inventory --graph
```

```sh
grep -n -E '^(kube_version|container_manager|kube_network_plugin|kube_proxy_mode|enable_nodelocaldns|cluster_name|kubeconfig_localhost):' \
  inventory/group_vars/k8s_cluster/k8s-cluster.yml
```

## The overrides of container nodes

Given: [`zz-containers.yml`](../group_vars/k8s_cluster/zz-containers.yml).
Read every comment **before** copying it: each override is something
Kubespray would otherwise do to the server you share with the room, or a
failure found on the dry run.

```sh
cp ~/trainings_exercises/f021bis/module2/lab3/group_vars/k8s_cluster/zz-containers.yml \
   inventory/group_vars/k8s_cluster/
```

## Commit before running

The cluster's definition is this commit: what `cluster.yml` will build is
what is in Git.

```sh
git add -A && git commit -m "spray: the decisions, container overrides"
```

## Questions

- Which of these would you choose differently on three VMs? On three bare
  metal servers in production?
- `zz-containers.yml` sets `kubelet_fail_swap_on: false`. Where else did this
  module refuse to `swapoff`, and why?
- Two files of `k8s_cluster/` set the same variable: which wins? And
  `group_vars/all/` against `group_vars/k8s_cluster/`?
