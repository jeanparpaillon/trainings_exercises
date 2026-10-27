# Step 3 — break it

**Slide:** Lab — network: break it · **~20 min**

Three overlays, each with one fault. Apply one, find the fault **from the
symptoms** (not by reading the overlay), then repair by re-applying step 2.
Work in pairs: one breaks, the other diagnoses.

```sh
kubectl -n "$NS" apply -k network/step3-break/<selector|targetport|host>
curl -s -o /dev/null -w '%{http_code}\n' \
  http://wordpress-gw.$NS.195.35.2.222.nip.io/
```

## Where to look, in this order

```sh
kubectl -n "$NS" get httproute wordpress -o yaml       # status, hostnames
kubectl -n "$NS" get svc wordpress -o yaml             # selector, ports
kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=wordpress
kubectl -n "$NS" get pods -l app=wordpress --show-labels
kubectl -n "$NS" exec deploy/toolbox -- wget -qO- -T 3 http://wordpress/ | head -c 200
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
- Did the module 1 Ingress (`wordpress.<ns>…`) keep working during the
  `host` fault? During the other two?
