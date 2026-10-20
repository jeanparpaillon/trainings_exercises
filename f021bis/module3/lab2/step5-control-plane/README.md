# Step 5 — the control plane

**Slides:** *Discovering Kubernetes: templates and LLD* · **~15 min**

Step 3 discovered five component hosts. Look at what each collects:
*Monitoring → Latest data*, host by host.

| Host | Reads | Collects? |
| --- | --- | --- |
| `API mon-<name>-control-plane` | `https://<node IP>:6443/metrics` | |
| `Kubelet mon-<name>-…` (two) | `https://<node IP>:10250` | |
| `Controller manager mon-<name>-control-plane` | `https://<node IP>:10257/metrics` | |
| `Scheduler mon-<name>-control-plane` | `https://<node IP>:10259/metrics` | |

The URLs are the hosts' macros (`{$KUBE.CONTROLLER.SERVER.URL}`…), set by
discovery.

## Two of them collect nothing

The controller manager's and the scheduler's items have **no data, no
error**, and **no problem** is raised: nothing in *Monitoring → Problems*
says that two components of your control plane are not monitored. Only
*Latest data* shows it. (The proxy treats a refused connection as the
target being unreachable, not the item as unsupported.)

One level down, as in module 1:

```sh
CP=$(kubectl get node "$CLUSTER-control-plane" -o jsonpath='{.status.addresses[0].address}')
kubectl -n monitoring exec deploy/zabbix-zabbix-helm-chart-proxy -- sh -c "nc -z -w2 $CP 10257; echo rc=\$?"
docker exec "$CLUSTER-control-plane" grep bind-address \
  /etc/kubernetes/manifests/kube-controller-manager.yaml /etc/kubernetes/manifests/kube-scheduler.yaml
```

`rc=1`, and `--bind-address=127.0.0.1`: kubeadm (and kind) bind both to
the loopback of the node. The API server listens on the node's address,
the kubelet too.

## The fix

```sh
for c in kube-controller-manager kube-scheduler; do
  docker exec "$CLUSTER-control-plane" sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/' \
    /etc/kubernetes/manifests/$c.yaml
done
kubectl -n kube-system get pods -l tier=control-plane -w      # the kubelet restarts both; Ctrl-C
```

On a dry run the controller manager's first values came 45 s later — and
its host went to ~2000 items: its template discovers metrics by
controller.

## Questions

- Why is that a security decision on a production cluster? (The metrics
  port open on the node network; who may read `/metrics` — both require
  authentication, and the chart's ClusterRole grants `get /metrics`.)
- How would you make it permanent? `docker exec … sed` is undone by the
  next `kubeadm upgrade`: kubeadm's `ClusterConfiguration`
  (`controllerManager.extraArgs`, `scheduler.extraArgs`). Module 2's
  Kubespray (v2.32.0) already binds both to `"::"` by default
  (`kube_controller_manager_bind_address`, `kube_scheduler_bind_address`):
  which is the better default, and who chose it for your clusters?
- etcd's metrics are on `127.0.0.1:2381` too (`--listen-metrics-urls`).
  Not done here: what would it take, and is it worth it?
- Nothing alerted while two components were unmonitored. What trigger
  would you add, and on which host — yours, since the discovered hosts are
  not?
