# Step 3 — fix and compare

**Slide:** Lab — tracing: fix and compare · **~10 min**

HotROD's bottlenecks are deliberate, and each has a command-line switch.
[`kustomization.yaml`](kustomization.yaml) adds two of them to the
container's `args`:

- `--fix-disable-db-conn-mutex`: no lock around the MySQL connection;
- `--fix-route-worker-pool-size=100`: route calls in parallel instead of
  three at a time.

In a real application, these would be a code change and a new image —
found the same way.

```sh
kubectl -n "$NS" apply -k tracing/step3-fix
kubectl -n "$NS" rollout status deploy/hotrod
kubectl -n "$NS" logs deploy/hotrod | grep fix:      # both fixes announced
```

Then the same load as in step 2:

```sh
HOTROD=http://hotrod.$NS.195.35.2.222.nip.io
for c in 123 392 567 731 123; do
  curl -s -o /dev/null -w '%{time_total}s\n' "$HOTROD/dispatch?customer=$c&nonse=$RANDOM" &
done; wait
```

## Compare

Jaeger keeps the traces from before the fix (same Jaeger pod, in memory).
In Grafana: Explore, **Split**, a trace from before on the left, one from
after on the right. In the Jaeger UI: **Search** → `frontend` · `GET
/dispatch`, tick one trace from before and one from after → **Compare
Traces**: the two span trees merged, the differences highlighted.

## Questions to answer before moving on

- `/dispatch` under load: how long **before**, how long **after**?
- What is the longest span **now**? Is it a bug, or a fact of life?
- The fix did not add a single CPU or replica. What would an HPA on CPU
  have done during step 2?

## Clean up

```sh
kubectl -n "$NS" delete -k tracing/step3-fix
```
