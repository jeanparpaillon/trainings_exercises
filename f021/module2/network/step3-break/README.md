# Step 3 — break it

**Slide:** Lab — network: break it · **~20 min**

Three overlays, each with one fault. Apply one, find the fault **from the
symptoms** (not by reading the overlay), then repair by re-applying step 2.
Work in pairs: one breaks, the other diagnoses.

```sh
kubectl -n "$NS" apply -k network/step3-break/<selector|targetport|host>
curl -s -o /dev/null -w '%{http_code}\n' \
  http://bookinfo-gw.$NS.195.35.2.222.nip.io/productpage
```

## Where to look, in this order

```sh
kubectl -n "$NS" get httproute bookinfo -o yaml        # status, hostnames
kubectl -n "$NS" get svc productpage -o yaml           # selector, ports
kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=productpage
kubectl -n "$NS" get pods -l app=productpage --show-labels
kubectl -n "$NS" exec deploy/toolbox -- wget -qO- -T 3 http://productpage:9080/productpage
```

| Symptom | Likely cause |
| --- | --- |
| 404 from Traefik | no route for this host / path |
| 503 from Traefik | route found, Service has no endpoints |
| 502 / timeout | endpoints exist, nothing answers on the port |

## Repair

```sh
kubectl -n "$NS" apply -k network/step2-gateway
```

## Questions to answer before moving on

- Which of the three faults leaves the EndpointSlice empty? Which one
  doesn't, and why is it harder to spot?
- Did the module 1 Ingress keep working during the `host` fault? During
  the other two?
