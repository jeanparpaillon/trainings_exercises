# Step 1 — names, from the inside

**Slide:** Lab — network: names · **~15 min**

No manifest: the `toolbox` pod of module 1 is enough.

```sh
kubectl -n "$NS" exec -it deploy/toolbox -- sh
```

Inside the pod:

```sh
cat /etc/resolv.conf                         # search list, ndots:5
nslookup productpage                         # short name
nslookup productpage.$NS                     # <svc>.<ns>
nslookup productpage.$NS.svc.cluster.local   # FQDN
nslookup mysql-0.mysql-headless              # one pod of a StatefulSet (module 2 storage)
wget -qO- http://productpage:9080/api/v1/products | head -c 200
```

`$NS` is not set inside the pod: type your namespace.

## Another namespace

Pick a neighbour's namespace (`kubectl get ns`) and call their Bookinfo:

```sh
wget -qO- -T 3 http://productpage.<their-ns>:9080/api/v1/products | head -c 200
```

It answers: the pod network is flat, and a namespace separates **names**,
not **traffic**. Step 4 changes that for your namespace.

## Endpoints

Out of the pod:

```sh
kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=reviews
kubectl -n "$NS" get pods -l app=reviews -o wide        # same IPs
```

## Questions to answer before moving on

- `nslookup productpage` from a pod in another namespace: what does it
  find?
- `nslookup www.google.com`: how many queries does the resolver send
  before the real one? (`ndots:5` and the search list)
- What changes in the EndpointSlice when you scale `reviews-v1` to 0?
