# Step 4 — default deny

**Slide:** Lab — network: default deny · **~20 min**

By default every pod accepts traffic from every pod of the cluster (step 1).
A NetworkPolicy that selects a pod turns that pod into "deny unless
allowed".

## Deny everything

```sh
kubectl -n "$NS" apply -k network/step4-netpol/deny
kubectl -n "$NS" get networkpolicy
```

Then try, and note what fails:

```sh
curl -s -o /dev/null -w '%{http_code}\n' -m 5 \
  http://bookinfo-gw.$NS.195.35.2.222.nip.io/productpage
kubectl -n "$NS" exec deploy/toolbox -- nslookup productpage
kubectl -n "$NS" exec deploy/toolbox -- wget -qO- -T 3 http://details:9080/details/0
```

## Allow what is needed

```sh
kubectl -n "$NS" apply -k network/step4-netpol/allow
```

Read [`allow/allow.yaml`](allow/allow.yaml): DNS, same namespace, Traefik
to the two front ends. The site answers again, and so does WordPress.

Ask a neighbour to call your Bookinfo from their toolbox
(`wget -qO- -T 3 http://productpage.<your-ns>:9080/productpage`): it now
times out.

## Clean up

```sh
kubectl -n "$NS" delete networkpolicy default-deny allow-dns \
  allow-same-namespace allow-from-traefik
```

The next modules (Prometheus scraping your pods, load tests) assume an
open namespace. Module 5 comes back to NetworkPolicies.

## Questions to answer before moving on

- Without `allow-dns`, which error does `wget http://details:9080` give?
  Why is it not a "connection refused"?
- Prometheus (namespace `monitoring`) scrapes your pods in module 4. What
  would it need here?
- A NetworkPolicy is enforced by the CNI, not by Kubernetes. What happens
  on a cluster whose CNI does not implement them?
