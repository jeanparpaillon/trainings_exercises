# Step 2 — an HTTPRoute

**Slide:** Lab — network: Gateway API · **~15 min**

The module 1 Ingress stays; this step adds an HTTPRoute to the same
`productpage` Service, on a second host name.

```sh
kubectl get gatewayclass                         # traefik
kubectl -n traefik get gateway traefik-gateway   # the shared Gateway

sed "s/CHANGEME/$NS/g" network/step2-gateway/httproute.yaml.tmpl \
  > network/step2-gateway/httproute.yaml
kubectl -n "$NS" apply -k network/step2-gateway
```

## Validate

```sh
kubectl -n "$NS" get httproute bookinfo
kubectl -n "$NS" get httproute bookinfo \
  -o jsonpath='{range .status.parents[*].conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
# Accepted=True, ResolvedRefs=True

curl -sI http://bookinfo-gw.$NS.195.35.2.222.nip.io/productpage   # 200
```

## Questions to answer before moving on

- Compare `kubectl -n "$NS" get ingress bookinfo -o yaml` and the
  HTTPRoute: who owns which part? Who could change the Gateway?
- The Ingress had no `status` worth reading. What does the HTTPRoute's
  status tell you that the Ingress could not?
- Change the `backendRefs` port to `9081` and re-apply: which condition
  changes? Put it back.
