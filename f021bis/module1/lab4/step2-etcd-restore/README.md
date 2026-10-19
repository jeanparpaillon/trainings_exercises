# Step 2 — restore etcd

**Slide:** etcd: snapshot and restore · **~20 min**

## The disaster

```sh
kubectl delete ns bookinfo
stars                                            # 0
```

**Hypothesis first:** after restoring the snapshot of step 1, is
`bookinfo` back? The `after-snapshot` ConfigMap?

## Restore

A restore makes a **new** etcd data directory from the snapshot. Write it
next to the current one — `restored/` inside `/var/lib/etcd`, which is the
path the etcd container sees — with this member's name and peer URL:

```sh
ip=$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' prod-control-plane)
etcdutl prod-control-plane snapshot restore /var/lib/etcd/snap.db \
  --data-dir /var/lib/etcd/restored \
  --name prod-control-plane \
  --initial-cluster "prod-control-plane=https://$ip:2380" \
  --initial-advertise-peer-urls "https://$ip:2380" \
  --bump-revision 1000000000 --mark-compacted
```

`--bump-revision` / `--mark-compacted`: every client of the API (kubelets,
kube-proxy, controllers, CoreDNS, Linkerd) is watching from a revision
*newer* than the snapshot. Without them, those watches resume in the
restored past and miss every change until the revision catches up — on a
dry run without them, kube-proxy never re-created the NodePort rules and
the page stayed dark. Bumped and marked compacted, every watch gets
"compacted", and its client lists everything again.

Now swap the data directory under the static pods, API server first out,
last in:

```sh
docker exec -it prod-control-plane bash
```

```sh
mkdir -p /root/manifests
mv /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/manifests/etcd.yaml /root/manifests/
while crictl ps -q --name '^(etcd|kube-apiserver)$' | grep -q .; do sleep 1; done
mv /var/lib/etcd/restored /var/lib/etcd-restored
grep -n -A1 'path: /var/lib/etcd$' /root/manifests/etcd.yaml
sed -i 's#path: /var/lib/etcd$#path: /var/lib/etcd-restored#' /root/manifests/etcd.yaml
mv /root/manifests/etcd.yaml /etc/kubernetes/manifests/
sleep 10
mv /root/manifests/kube-apiserver.yaml /etc/kubernetes/manifests/
exit
```

The old data stays in `/var/lib/etcd`: going back is putting the hostPath
back.

## Check

```sh
until kubectl get --raw /readyz >/dev/null 2>&1; do sleep 2; done
kubectl get ns
kubectl -n default get configmap after-snapshot
kubectl -n bookinfo get pods -o wide
```

The Pods are back as *objects* — their containers were killed with the
namespace. The restore guide says to restart the components that act on
what is in etcd; do it, then look again:

```sh
for n in prod-control-plane prod-worker; do docker exec $n systemctl restart kubelet; done
docker exec prod-control-plane sh -c \
  'for c in kube-controller-manager kube-scheduler; do crictl stop $(crictl ps -q --name "^$c$"); done'
kubectl -n bookinfo rollout status deploy --timeout=5m
stars                                            # 9
```

Fill the etcd row of the table in [`../README.md`](../README.md): namespace
back, ConfigMap made after the snapshot gone — the whole cluster went back
in time, not only what you deleted.

## Questions

- etcd holds objects only. Had `bookinfo` carried a PersistentVolume, what
  would the restored PV have pointed at?

- What else went back in time that you did not look at? (Leases, node
  heartbeats, EndpointSlices, Helm release Secrets, ReplicaSet revisions.)
- In a 3-member cluster: how many snapshots, how many restores, and why
  must all members start from the *same* snapshot?
- Where would `snap.db` have come from if the node itself was lost?
