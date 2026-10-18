# Lab 3 — Kubespray

**Slides:** *Session 2* (`ansible_k8s.md`, Kubespray part), *Session 4*
(`kubespray.md`), then *Lab 3* (`lab_kubespray_init.md`,
`lab_kubespray_ops.md`, `lab_kubespray_upgrade.md`)

Lab 1's inventory becomes a Kubernetes cluster, `spray`: Kubespray's
playbooks, our inventory. Then the day-2 operations module 1 did by hand —
add a node, remove one, upgrade — each as an inventory change and a
playbook. It ends with lab 2's `flux.yml` on `spray`: from empty containers
to GitOps, every step is code.

| Part | Step | | ~ |
| --- | --- | --- | --- |
| 3a — deploy (session 4) | [step1-layout](step1-layout/) | Kubespray's layout, our inventory, `ansible.cfg` | 10 min |
| | [step2-vars](step2-vars/) | `group_vars`: the decisions, the container overrides | 15 min |
| | [step3-cluster](step3-cluster/) | `cluster.yml` | 35 min |
| | [step4-smoke](step4-smoke/) | kubeconfig, smoke tests, where things run | 15 min |
| 3b — day 2 (session 4) | [step5-scale](step5-scale/) | add `node3`: `scale.yml` | 15 min |
| | [step6-remove](step6-remove/) | remove `node2`: `remove-node.yml` | 20 min |
| 3c — upgrade (session 5) | [step7-baseline](step7-baseline/) | baseline under load | 10 min |
| | [step8-upgrade](step8-upgrade/) | `upgrade-cluster.yml`, `KUBE_FROM` → `KUBE_TO` | 30 min |
| | [step9-chain](step9-chain/) | the whole chain: lab 2's `flux.yml` on `spray` | 10 min |

| File | What it is |
| --- | --- |
| [`group_vars/k8s_cluster/zz-containers.yml`](group_vars/k8s_cluster/zz-containers.yml) | the overrides that exist only because the nodes are containers, each explained |
| [`step6-remove/web.yaml`](step6-remove/web.yaml) | Deployment `web` + PDB, for steps 6–8 |
| [`step7-baseline/web-nodeport.yaml`](step7-baseline/web-nodeport.yaml) | `web` on NodePort 30082 |
| [`load`](load) | `curl` every 0.2 s to both nodes' NodePort, failures with timestamps |
| [`solution-3a/`](solution-3a/) | `~/m2` at the end of 3a (`make catch-up-lab3a`) |
| [`solution/`](solution/) | `~/m2` at the end of the lab; vaults encrypted with `m2-solution` |

**Start**: lab 2 done (`iac` deleted), nodes up, `~/kubespray` at
`KUBESPRAY_VERSION`, the venv active; the trainer ran `predownload`.

```sh
source ~/.venvs/m2/bin/activate
cd ~/m2
export KUBECONFIG=~/m2/inventory/artifacts/admin.conf     # from step 4 on, in every tab
```

| End of | State | Catch-up |
| --- | --- | --- |
| 3a | `spray` at `KUBE_FROM`: `node1` control plane + etcd + worker, `node2` worker | `make catch-up-lab3a` (recreates the nodes) |
| 3b | `node1` + `node3`; `node2` reset, in `spare` | — |
| 3c | `spray` at `KUBE_TO`, Flux reconciling `lab2/fleet` | — |

Delete everything at the end of the module: `make -C lab0 down`.

## What was found on the dry run

Run end to end on 2026-10-17/18 on a laptop (Linux 7.0, Docker, cgroup v2,
4 cores, 15 GiB), not on the server: the `lab0` nodes, Kubespray v2.32.0
(ansible-core 2.19), 1.35.8 → 1.36.4, flannel. **Kubespray runs on container
nodes**, with the overrides of `zz-containers.yml` and three fixes in the
node image.

Failures, in the order they came — each is now an override or an image fix:

| Run | Failed at | Cause | Fix |
| --- | --- | --- | --- |
| 1 | `Stop if access_ip is not pingable` | no `ping` in the image | `iputils-ping` in `lab0/node/Dockerfile` |
| 2 | `Add domain/search/nameservers/options to resolv.conf` | `/etc/resolv.conf` is bind-mounted (`Errno 16`) | `resolvconf_mode: none` |
| 3 | `kubeadm init` preflight | `SystemVerification`: no kernel config in a container | `kubeadm_ignore_preflight_errors` |
| 4 | `kubeadm init`, timeout | kubelet: `open /run/systemd/resolve/resolv.conf` — Kubespray's Ubuntu vars, not overridable | the entrypoint writes that file |
| 9 | `flux.yml`: Kustomization never `Ready` | `cluster_name: spray.local` also made the DNS domain `spray.local`; Flux's `install.yaml` hardcodes `svc.cluster.local` | `dns_domain: cluster.local` (step 2); a cluster rebuild, DNS domains do not change in place |
| 9 again | same | `dns_domain` added near `cluster_name`, but the sample sets it again further down: the last key wins (`[WARNING]: Found duplicate mapping key`) | edit the sample's line instead (step 2 says so) |

Found by reading Kubespray before running it, and verified after (the
server's — here the laptop's — global sysctls and swap were unchanged by the
whole lab):

- `swapoff -a` (`kubelet_fail_swap_on`), `kernel.panic*`/`vm.*`/`kernel.keys.*`
  (`kubelet_protect_kernel_defaults`), raised `fs.inotify.*`, `fs.aio-max-nr`,
  `kernel.pid_max`, `vm.max_map_count`, `nf_conntrack_max` (`sysctl_minimum_values`,
  role vars: only the `additional_sysctl_min` floor of 0 neutralises them),
  conntrack sizing by kube-proxy. All overridden.
- Downloads went to `/tmp/releases` — a tmpfs in the nodes: ~460 MB of RAM
  each, gone at every restart. `local_release_dir: /var/tmp/releases`.
- Kernel modules still land in the server's kernel: `br_netfilter`,
  `overlay`, `nf_conntrack`, `vxlan` (flannel). Load them on the server
  beforehand.

Measured:

| Step | Time | Notes |
| --- | --- | --- |
| 3 `cluster.yml`, binaries cached | 8 min 6 s | ~5 min of image pulls |
| 3 `cluster.yml`, nothing cached | ~44 min | ~40 min of binary downloads on that link: predownload matters |
| 5 `facts.yml` + `scale.yml --limit=node3` | 3 min 48 s | `changed=0` on node1/node2 |
| 6 `remove-node.yml -e node=node2` | 54 s | PDB respected, one pod at a time |
| 8 `upgrade-cluster.yml` | 16 min (961 s) | ~10 min of downloads; **1 failed request of ~4,300** |
| 9 `flux.yml` on `spray` | 64 s | Kustomization `Ready`, podinfo on both nodes |
| the chain from blank nodes: `site.yml` + `cluster.yml` + `flux.yml`, `solution-3a` as is | 19 s + 4 min 32 s + 64 s | binaries cached, images pulled |

Design decisions taken on the way:

- **`ansible.cfg` carries Kubespray's settings** (`roles_path`, `library`,
  fact cache, `ignore_patterns = artifacts`, pipelining): we run its
  playbooks from `~/m2`, so `~/kubespray/ansible.cfg` does not apply.
  Without `roles_path` nothing runs; without the fact cache `scale.yml
  --limit` has no facts for the other nodes; without `ignore_patterns`
  `admin.conf` is parsed as inventory.
- **`node1` is in `kube_node`** (step 2): untainted, so that with two nodes
  the upgrade can drain one while the other keeps `web`. The upgrade run
  started from a cluster created without it (the taint was removed by
  `upgrade-cluster.yml`, `Remove taint for control plane node with node
  role`); the final chain run created it with it: no taint from the start.
- The spec's `k8s_cluster` group is explicit in our inventory; Kubespray
  also builds it (`roles/dynamic_groups`). No conflict.

Not validated yet: `make -C lab0 predownload` (`cluster.yml --tags
download`) and whether the next `cluster.yml` then skips downloading; four
pairs at once on the server's 4 CPUs; the server's kernel (modules
available under `/lib/modules`, its iptables backend).
