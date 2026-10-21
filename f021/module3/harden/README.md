# Harden the application

Make Bookinfo survive the failures the platform handles — restarts,
rollouts, evictions — with probes, graceful shutdown, replicas and
budgets. Starts from the end of the autoscale lab
(`autoscale/step6-hpa-rps`); every path below is relative to `module3/`.

```sh
export NS=<your-namespace>
cd module3
kubectl -n "$NS" get deploy wordpress    # still 0 replicas: keep it so (quota)
```

| | Step | Slide | ~ |
| --- | --- | --- | --- |
| 1 | `step1-baseline` | Lab — baseline under load | 15 min |
| 2 | `step2-probes` | Lab — probes done right | 20 min |
| 3 | `step3-shutdown` | Lab — graceful shutdown | 15 min |
| 4 | `step4-spread` | Lab — replicas and budgets | 15 min |
| 5 | `step5-timeouts` | Lab — timeouts in the client (optional) | 10 min |
| 6 | `step6-fallback` | Lab — fallback (optional) | 5 min |

## The load generator

k6 at a constant 20 requests per second for 3 minutes, against
`productpage`. One fresh run per experiment, the action ~20 s in:

```sh
kubectl -n "$NS" delete job k6 --ignore-not-found
kubectl -n "$NS" apply -f harden/k6/constant-load.yaml
kubectl -n "$NS" logs -f job/k6 -c k6
```

Three numbers each time: **failed requests** (`http_req_failed`),
**degraded pages** (the `… shown` checks: productpage answers 200 with an
apology when a dependency fails), **p99**. Keep a table, one row per step
and operation.

## Step 1 — baseline under load

```sh
kubectl -n "$NS" apply -k harden/step1-baseline
```

One k6 run per operation:

```sh
kubectl -n "$NS" rollout restart deploy/reviews-v2
kubectl -n "$NS" rollout restart deploy/reviews-v1 deploy/reviews-v2 deploy/reviews-v3
kubectl -n "$NS" rollout restart deploy/productpage-v1
kubectl -n "$NS" delete pod -l app=productpage
```

**Questions:** a 200 saying "reviews unavailable": failed or not? Restarting
`reviews-v2` alone may cost nothing — why? (`range(2)` in `productpage.py`)

## Step 2 — probes done right

```sh
kubectl -n "$NS" apply -k harden/step2-probes
kubectl -n "$NS" get pods -w                        # reviews 0/1 → 1/1
kubectl -n "$NS" get events --field-selector reason=Unhealthy
```

Read [`step2-probes/probes.yaml`](step2-probes/probes.yaml), then replay
"restart all reviews": fewer degraded pages?

**The trap.** First a slow dependency with the sane probes — degraded, not
down:

```sh
kubectl -n "$NS" apply -f harden/faults/ratings-blackhole.yaml
kubectl -n "$NS" scale deploy/ratings-v1 --replicas=0
```

Then a liveness probe that "checks everything":

```sh
kubectl -n "$NS" patch deploy productpage-v1 \
  --patch-file harden/step2-probes/trap-liveness.yaml
kubectl -n "$NS" get pods -l app=productpage -w     # RESTARTS climb
```

**Undo both:**

```sh
kubectl -n "$NS" apply -k harden/step2-probes       # also ratings-v1 back to 1
kubectl -n "$NS" delete -f harden/faults/ratings-blackhole.yaml
```

**Questions:** why was a healthy pod killed, and what did the restart fix?
What if `reviews` were only ready when `ratings` answers?

## Step 3 — graceful shutdown

Replay "restart productpage" under load and watch the non-200s:

```sh
linkerd -n "$NS" viz tap deploy/productpage-v1 --path /productpage | grep -v ':status=200'
```

Then apply the fix (`preStop` sleep 5 s, grace period written out) and
restart again — target: **zero** failed requests.

```sh
kubectl -n "$NS" apply -k harden/step3-shutdown
```

**Questions:** what was failing before `preStop`? Who decides the 5 s? What
must the application code do on SIGTERM?

## Step 4 — replicas and budgets

```sh
kubectl -n "$NS" apply -k harden/step4-spread
kubectl -n "$NS" get pods -o wide -l 'app in (productpage,reviews)'
kubectl -n "$NS" get pdb                            # ALLOWED DISRUPTIONS 1
```

`productpage` (through its HPA minimum) and `reviews-v2` now run two
replicas, each with a PDB `minAvailable: 1`. The shared cluster has one
node, so you cannot drain it: call the **eviction API** yourself, as
`kubectl drain` does, on both pods of `reviews-v2`, quickly:

```sh
for POD in $(kubectl -n "$NS" get pod -l app=reviews,version=v2 -o name | cut -d/ -f2); do
  echo "{\"apiVersion\":\"policy/v1\",\"kind\":\"Eviction\",\"metadata\":{\"name\":\"$POD\"}}" \
    | kubectl create --raw "/api/v1/namespaces/$NS/pods/$POD/eviction" -f -
done
```

The first eviction is accepted; the second is refused (429, "would violate
the pod's disruption budget") until the replacement is Ready. Then compare
with `kubectl delete pod` on both: the PDB does not see it.

**Questions:** which disruptions does a PDB not protect against? What
happens to a drain with `minAvailable: 1` on a one-replica Deployment?
`details` and `ratings` have one replica and no PDB: is that a choice you
can defend?

## Step 5 (optional) — timeouts in the client

The Bookinfo images hardcode their timeouts: productpage → reviews 3 s and
one retry; reviews v2 → ratings 10 s; v3 → ratings 2.5 s. Observe them:

- **dead**: scale every `reviews` to 0, time the page
- **slow**: the ratings black hole of step 2, time each reviews version
  from the toolbox (`time wget -qO- http://<pod-ip>:9080/reviews/0`)

Put ratings back afterwards.

**Questions:** why is slow worse than dead? For a 2 s page budget, which
timeout per hop, in which code, how many releases?

## Step 6 (optional) — fallback

```sh
kubectl -n "$NS" scale deploy/ratings-v1 --replicas=0     # reload the page
kubectl -n "$NS" scale deploy/ratings-v1 --replicas=1
kubectl -n "$NS" exec deploy/productpage-v1 -c productpage -- \
  grep -n "currently unavailable" productpage.py
```

**Questions:** who decided the page survives without `ratings`? k6 counted
those pages as successes: what would you alert on?

## Afterwards

```sh
kubectl -n "$NS" delete -f harden/faults/ratings-blackhole.yaml --ignore-not-found
kubectl -n "$NS" delete job k6 --ignore-not-found
kubectl -n "$NS" apply -k harden/step4-spread
kubectl -n "$NS" scale deploy/wordpress sts/mysql --replicas=1
```

WordPress comes back now that the module is over.
