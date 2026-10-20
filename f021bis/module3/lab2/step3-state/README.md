# Step 3 — cluster state

**Slides:** *Discovering Kubernetes: templates and LLD* · **~15 min**

The nodes template sees nodes and pods. The cluster state template sees
what Kubernetes **wants** against what it **has**: deployments, daemonsets,
statefulsets, replicasets, jobs, PVCs, endpoints — from the API and from
kube-state-metrics — and it discovers the control plane as hosts.

## The parent host

*Data collection → Hosts → Create host*: `<name> mon state`, template
*Kubernetes cluster state by HTTP*, group `<name>`, no interface,
monitored by proxy `<name>`, **the same three macros** as step 2.

Its master items run every minute. Then, *Monitoring → Hosts*:

- `API mon-<name>-control-plane`, `Controller manager …`, `Scheduler …`,
  `Kubelet mon-<name>-control-plane`, `Kubelet mon-<name>-worker`: one host
  per component, each with its own template (step 5);
- on `<name> mon state` itself, *Latest data*: the items per object.

## How many?

```sh
S=$(lab0/zapi host.get "{\"output\": [\"hostid\"], \"filter\": {\"host\": [\"$ZBX_USER mon state\"]}}" | jq -r '.[0].hostid')
lab0/zapi item.get "{\"output\": [\"key_\"], \"hostids\": [\"$S\"]}" \
  | jq -r 'length, (map(.key_ | capture("^kube\\.(?<k>[a-z_]+)") .k) | group_by(.) | map("\(.[0]) \(length)") | join(", "))'
```

On a dry run: **452 items**, 255 of them for pods (~17 per pod), on a
cluster with nothing but the system and the chart.

## Only the namespaces that matter

The templates filter discovery with macros; set them on **your** hosts:

| Host | Macro | Value |
| --- | --- | --- |
| `<name> mon state` | `{$KUBE.LLD.FILTER.NAMESPACE.MATCHES}` | `^(default|kube-system|podinfo)$` |
| `<name> mon nodes` | `{$KUBE.LLD.FILTER.POD.NAMESPACE.MATCHES}` | the same |

`podinfo` does not exist yet: lab 3's.

Count again after two minutes. A filter applies **at the next change of
what is discovered**: the discovery rules *discard unchanged* values (with a
3 h heartbeat), so a list that does not change is not processed again.
On the dry run the state host dropped to 304 items by itself; the nodes
host kept its pods of `monitoring` until the pod list changed:

```sh
kubectl -n kube-system rollout restart deploy/coredns     # new pod names: a new list
```

— 52 s later, 178 → 138 items.

## Questions

- What does that number become on your production cluster (namespaces,
  pods per namespace)? What does it cost on the server (items, history,
  the LLD processing on the proxy)?
- `kube-system` is kept: why would you want its pods, and which of them?
- *Discard unchanged with heartbeat*: what does it save, and what does it
  delay? (A filter, a template change: up to 3 h if nothing moves.)
