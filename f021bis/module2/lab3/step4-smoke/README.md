# Step 4 — kubeconfig, smoke tests, where things run

**Slides:** Kubespray — overview · **~15 min**

## The kubeconfig

`kubeconfig_localhost: true` copied the cluster-admin kubeconfig into the
inventory — git-ignored since lab 1 (`.gitignore`), and outside Ansible's
inventory parsing (`ignore_patterns` in `ansible.cfg`):

```sh
export KUBECONFIG=~/m2/inventory/artifacts/admin.conf
kubectl config current-context          # kubernetes-admin-spray.local@spray.local
git status --short                       # admin.conf must NOT show up
```

Keep this `export` in every tab of lab 3.

## The cluster

```sh
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

## Below the API

```sh
ssh node1 systemctl status etcd --no-pager       # etcd: a systemd unit
ssh node1 ls /etc/kubernetes/manifests           # no etcd.yaml
ssh node2 sudo crictl ps                          # nginx-proxy?
ssh node2 ls /etc/kubernetes/manifests          # a static pod, on a worker
ssh node2 sudo grep -A4 upstream /etc/nginx/nginx.conf
```

## Smoke tests

```sh
kubectl create deploy smoke --image=nginx:1.30.6-alpine --replicas=2
kubectl expose deploy smoke --port 80
kubectl rollout status deploy smoke
kubectl run t --image=busybox:1.37 --restart=Never --rm -it \
  --overrides='{"spec":{"nodeName":"node1"}}' -- \
  sh -c 'nslookup kubernetes.default.svc.cluster.local; nslookup github.com; wget -qO- smoke | grep title'
```

The test pod runs on `node1`. Look where `smoke`'s pods and CoreDNS run
(`kubectl get pods -A -o wide`): whatever answered from `node2` crossed the
flannel VXLAN between the nodes.

```sh
kubectl delete deploy,svc smoke
git add -A && git commit -m "spray up" --allow-empty && git tag lab3a
```

## Questions

- Compared with a kind cluster: what is the same (kubeadm, static pods for
  the control plane), what is not (etcd, the CNI, how the node got its
  binaries, the API load balancer on workers)?
- `nginx-proxy` on `node2`, not on `node1`: what is it for, and what would it
  change with three control planes?
- `kubectl describe node node1 | grep Taints`: why none, on a control plane?
  (Step 2, `kube_node`.)
